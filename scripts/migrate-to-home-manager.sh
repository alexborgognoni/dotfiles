#!/usr/bin/env bash
# Switch an Ubuntu machine from chezmoi to Home Manager.
#
#   1. moves every chezmoi-managed file into a timestamped backup
#   2. activates the Home Manager configuration (nix/homes/<machine>.nix)
#   3. moves binaries in ~/.local/bin and ~/.cargo/bin that Home Manager now
#      provides into the backup (Ubuntu puts ~/.local/bin first on PATH, so
#      they would shadow the Nix versions)
#
# Undo with scripts/rollback-to-chezmoi.sh. Requires Nix (see
# scripts/bootstrap-nix.sh) and the sops admin key in
# ~/.config/sops/age/keys.txt.
#
# Usage: scripts/migrate-to-home-manager.sh [config]   (default: alex@work-laptop)
set -euo pipefail

config="${1:-alex@work-laptop}"
dotfiles="$(cd "$(dirname "$0")/.." && pwd)"
flake="$dotfiles/nix"
state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-migration"
backup="$state/$(date +%Y%m%d-%H%M%S)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Single-user Nix installs need their profile script; multi-user ones load
# /etc/profile.d/nix.sh at login.
for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
  # shellcheck disable=SC1090
  [ -r "$f" ] && . "$f" && break
done
command -v nix >/dev/null || die "nix is not installed (run scripts/bootstrap-nix.sh)"
[ -r "$HOME/.config/sops/age/keys.txt" ] || die "missing sops admin key ~/.config/sops/age/keys.txt"

nixcmd() { nix --extra-experimental-features "nix-command flakes" "$@"; }

# Settings exported by the old shell configuration must not leak into the
# activation (Node 24 based tools like VS Code refuse the chezmoi-era
# NODE_OPTIONS="--use-openssl-ca --use-system-ca").
unset NODE_OPTIONS

log "Building $config (this can take a while the first time)"
nixcmd build --no-link "$flake#homeConfigurations.\"$config\".activationPackage"

mkdir -p "$backup/home" "$backup/bin"
echo "$config" > "$backup/config"

# 1. chezmoi-managed files
if command -v chezmoi >/dev/null && [ -d "$dotfiles/chezmoi" ]; then
  managed="$(chezmoi --source "$dotfiles/chezmoi" managed --include files,symlinks 2>/dev/null || true)"
else
  managed=""
fi
# Also the known chezmoi targets, in case chezmoi itself is gone.
managed="$(printf '%s\n' "$managed" .zshrc .zsh/aliases.zsh .zsh/functions.zsh .gitconfig .gitconfig-personal \
  .ssh/config .config/kitty/kitty.conf .config/kitty/startup.conf .config/tmux/tmux.conf \
  .config/starship.toml .config/bat/config .config/gh/config.yml | sort -u)"
# Links into the Nix store are Home Manager's own (a re-run): never move them
# (the path itself or any parent directory may be the link)
from_nix() { case "$(readlink -f "$1")" in /nix/store/*) true ;; *) false ;; esac; }

log "Moving chezmoi-managed files to $backup/home"
moved=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  src="$HOME/$rel"
  from_nix "$src" && continue
  if [ -e "$src" ] || [ -L "$src" ]; then
    mkdir -p "$backup/home/$(dirname "$rel")"
    mv "$src" "$backup/home/$rel"
    echo "$rel" >> "$backup/moved-files"
    moved=$((moved + 1))
  fi
done <<<"$managed"
# Whole AstroNvim config: now in the repo (nix/modules/home/editor/astronvim)
if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ] && ! from_nix "$HOME/.config/nvim/init.lua"; then
  mkdir -p "$backup/home/.config"
  mv "$HOME/.config/nvim" "$backup/home/.config/nvim"
  echo ".config/nvim" >> "$backup/moved-files"
  moved=$((moved + 1))
fi
log "Moved $moved paths"

# Record the backup now, so a failed activation can still be rolled back
if [ -s "$backup/moved-files" ]; then
  ln -sfn "$backup" "$state/latest"
fi

# zsh history: Home Manager's zsh reads it from the XDG state directory
history_new="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
if [ -s "$HOME/.zsh_history" ] && [ ! -e "$history_new" ]; then
  mkdir -p "$(dirname "$history_new")"
  cp -p "$HOME/.zsh_history" "$history_new"
  log "Copied zsh history ($(wc -l < "$HOME/.zsh_history") lines) to $history_new"
fi

# 2. activate
log "Activating Home Manager ($config)"
if ! nixcmd run "$flake#home-manager" -- switch --flake "$flake#$config" -b hm-backup; then
  die "activation failed; restore with scripts/rollback-to-chezmoi.sh $backup"
fi

# 3. shadowing binaries
profile_bin="$HOME/.nix-profile/bin"
[ -d "$profile_bin" ] || profile_bin="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager/home-path/bin"
log "Moving binaries now provided by Home Manager out of ~/.local/bin and ~/.cargo/bin"
for dir in "$HOME/.local/bin" "$HOME/.cargo/bin"; do
  [ -d "$dir" ] || continue
  for bin in "$dir"/*; do
    [ -f "$bin" ] || [ -L "$bin" ] || continue
    from_nix "$bin" && continue
    name="$(basename "$bin")"
    if [ -e "$profile_bin/$name" ]; then
      mkdir -p "$backup/bin/${dir#"$HOME"/}"
      mv "$bin" "$backup/bin/${dir#"$HOME"/}/$name"
      echo "${dir#"$HOME"/}/$name" >> "$backup/moved-bins"
    fi
  done
done
[ -f "$backup/moved-bins" ] && log "Moved $(wc -l < "$backup/moved-bins") binaries: $(tr '\n' ' ' < "$backup/moved-bins")"

# Only binaries moved on a re-run (e.g. after a failed activation): add them
# to the existing backup, so one backup holds everything for the rollback
if [ ! -s "$backup/moved-files" ] && [ -s "$backup/moved-bins" ] && [ -d "$state/latest" ]; then
  cp -a "$backup/bin/." "$state/latest/bin/" 2>/dev/null || { mkdir -p "$state/latest/bin" && cp -a "$backup/bin/." "$state/latest/bin/"; }
  cat "$backup/moved-bins" >> "$state/latest/moved-bins"
  rm -rf "$backup"
  log "Added the moved binaries to $(readlink -f "$state/latest")"
  exit 0
fi

# Nothing moved (already migrated): keep the previous backup as "latest", so
# rollback-to-chezmoi.sh still restores the real chezmoi files
if [ ! -s "$backup/moved-files" ] && [ ! -s "$backup/moved-bins" ]; then
  rm -rf "$backup"
  log "Already migrated; nothing moved (backup: $(readlink -f "$state/latest" 2>/dev/null || echo none))"
  exit 0
fi

ln -sfn "$backup" "$state/latest"
cat <<EOF

Done. Backup: $backup
Next steps:
  - open a new terminal (or log out and back in for GNOME app grid entries)
  - GPU drivers, keyd, the Hyprland session: system-manager (./install does it)
  - everyday:                   nh home switch
  - undo everything:            scripts/rollback-to-chezmoi.sh
EOF
