#!/usr/bin/env bash
# Snapshot everything the migration and cleanup could lose, before they run:
# one archive, encrypted to the sops admin age key (Bitwarden "sops-age-key").
#
#   scripts/snapshot-system.sh [output-dir]      (default: ~/Backups; asks for sudo)
#
# Contents:
#   home/   ~/.config (without browser/app caches), ~/.local/bin,
#           ~/.local/share/{applications,fonts,themes,icons}, ~/.icons,
#           ~/snap, ~/.var, shell dotfiles and history, ~/.ssh/config
#   etc/    all of /etc (root-only files included)
#   lists/  apt (manual, all, sources), snap, flatpak, pip --user, npm -g,
#           cargo, mise, nvm, bun, /opt, /usr/local
#
# Restore a file:  age -d -i ~/.config/sops/age/keys.txt <archive> | zstd -d | tar -x <path>
set -euo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

out="${1:-$HOME/Backups}"
recipient="$(grep -o 'age1[a-z0-9]*' "$dotfiles/nix/.sops.yaml" | head -1)" # admin key
stamp="$(date +%Y%m%d-%H%M%S)"
archive="$out/system-snapshot-$(hostname)-$stamp.tar.zst.age"

[ -n "$recipient" ] || die "no age recipient in nix/.sops.yaml"
if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
command -v nix >/dev/null || die "needs Nix (scripts/bootstrap-nix.sh)"
nixtool() { nix --extra-experimental-features "nix-command flakes" shell "nixpkgs#$1" -c "${@:2}"; }

work="$(mktemp -d)"
trap 'sudo rm -rf "$work"' EXIT
mkdir -p "$work/lists" "$out"

log "Package and install lists"
L="$work/lists"
apt-mark showmanual >"$L/apt-manual.txt"
dpkg-query -W -f '${Package}\t${Version}\n' >"$L/apt-all.txt"
cp -r /etc/apt "$L/etc-apt" 2>/dev/null || true
snap list >"$L/snap.txt" 2>&1 || true
flatpak list --app >"$L/flatpak.txt" 2>&1 || true
python3 -m pip list --user --format=freeze >"$L/pip-user.txt" 2>&1 || true
{ for d in "$HOME"/.nvm/versions/node/*/lib/node_modules; do [ -d "$d" ] && echo "== $d" && ls "$d"; done; } >"$L/npm-global.txt" 2>&1 || true
ls -la "$HOME/.cargo/bin" >"$L/cargo-bin.txt" 2>&1 || true
ls "$HOME/.local/share/mise/installs" >"$L/mise.txt" 2>&1 || true
ls -la "$HOME/.bun/install/global/node_modules" >"$L/bun-global.txt" 2>&1 || true
ls -la /opt /usr/local/bin /usr/local/lib/systemd/system >"$L/opt-usr-local.txt" 2>&1 || true
systemctl list-unit-files --state=enabled >"$L/systemd-enabled.txt" 2>&1 || true
systemctl --user list-unit-files --state=enabled >"$L/systemd-user-enabled.txt" 2>&1 || true

log "Home files"
paths=()
for p in .config .local/bin .local/share/applications .local/share/fonts .local/share/themes \
  .local/share/icons .icons .themes snap .var .zsh_history .zshrc .zshenv .zprofile .zsh \
  .bashrc .bash_history .profile .gitconfig .gitconfig-personal .ssh/config .Xmodmap .env.sh; do
  [ -e "$HOME/$p" ] && paths+=("$p")
done
tar -C "$HOME" -cf "$work/home.tar" \
  --exclude='.config/google-chrome*' --exclude='.config/microsoft-edge' --exclude='.config/chromium' \
  --exclude='.config/gcloud/logs' --exclude='.config/Code/Cache*' --exclude='.config/Code/CachedData' \
  --exclude='.config/Code/User/workspaceStorage' --exclude='.config/*/Cache' --exclude='.config/*/GPUCache' \
  --exclude='.config/*/Code Cache' --exclude='.config/open-whispr/models' --exclude='*/node_modules' \
  "${paths[@]}"

log "/etc (sudo)"
sudo tar -C / -cf "$work/etc.tar" etc 2>/dev/null || sudo tar -C / --ignore-failed-read -cf "$work/etc.tar" etc
sudo chown "$(id -u):$(id -g)" "$work/etc.tar"

log "Encrypting to the sops admin key"
tar -C "$work" -cf - lists home.tar etc.tar |
  nixtool zstd zstd -q -T0 -19 |
  nixtool age age -r "$recipient" >"$archive"

log "Snapshot: $archive ($(du -h "$archive" | cut -f1))"
echo "Copy it off this machine too (e.g. OneDrive)."
