#!/usr/bin/env bash
# Undo scripts/migrate-to-home-manager.sh: remove the Home Manager
# generation (files and packages) and restore the backed-up chezmoi files and
# binaries. Nix itself stays installed.
#
# Usage: scripts/rollback-to-chezmoi.sh [backup-dir]   (default: the latest)
set -euo pipefail

state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-migration"
backup="${1:-$state/latest}"
backup="$(readlink -f "$backup")"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$backup/home" ] || die "no migration backup at $backup"
for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
  # shellcheck disable=SC1090
  [ -r "$f" ] && . "$f" && break
done

if command -v home-manager >/dev/null; then
  log "Removing the Home Manager generation"
  home-manager uninstall <<<"y" || die "home-manager uninstall failed"
fi

log "Restoring files from $backup"
if [ -f "$backup/moved-files" ]; then
  while IFS= read -r rel; do
    mkdir -p "$HOME/$(dirname "$rel")"
    rm -rf "${HOME:?}/$rel"
    mv "$backup/home/$rel" "$HOME/$rel"
  done < "$backup/moved-files"
fi
if [ -f "$backup/moved-bins" ]; then
  while IFS= read -r rel; do
    mkdir -p "$HOME/$(dirname "$rel")"
    mv "$backup/bin/$rel" "$HOME/$rel"
  done < "$backup/moved-bins"
fi

rm -f "$state/latest"
log "Restored. Open a new terminal; run 'chezmoi apply' if you changed chezmoi files since."
