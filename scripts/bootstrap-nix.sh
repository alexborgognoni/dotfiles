#!/usr/bin/env bash
# Install Nix (multi-user daemon) on Ubuntu and configure it for corporate
# TLS inspection (Zscaler): the system CA bundle, which already contains the
# corporate root, is used by the daemon and inside the build sandbox.
# Idempotent; asks for sudo. Afterwards: scripts/migrate-to-home-manager.sh
set -euo pipefail

ca=/etc/ssl/certs/ca-certificates.crt
user="$(id -un)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run as your user, not root"
[ -r "$ca" ] || die "missing $ca"
command -v systemctl >/dev/null || die "systemd is required for the Nix daemon"

if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  log "Installing Nix (multi-user)"
  installer="$(mktemp)"
  curl -fsSL https://nixos.org/nix/install -o "$installer"
  sh "$installer" --daemon --yes
  rm -f "$installer"
else
  log "Nix is already installed"
fi

log "Configuring /etc/nix/nix.conf"
conf="$(mktemp)"
sudo cat /etc/nix/nix.conf 2>/dev/null | sed '/^# BEGIN dotfiles$/,/^# END dotfiles$/d' > "$conf" || true
cat >> "$conf" <<EOF
# BEGIN dotfiles
experimental-features = nix-command flakes
trusted-users = root $user
auto-optimise-store = true
# Corporate CA (Zscaler): for the daemon's downloads and for source fetches
# inside the build sandbox
ssl-cert-file = $ca
extra-sandbox-paths = $ca
# END dotfiles
EOF
sudo install -m 644 "$conf" /etc/nix/nix.conf
rm -f "$conf"

log "Configuring the nix-daemon environment"
sudo mkdir -p /etc/systemd/system/nix-daemon.service.d
printf '[Service]\nEnvironment=NIX_SSL_CERT_FILE=%s\nEnvironment=NIX_GIT_SSL_CAINFO=%s\n' "$ca" "$ca" \
  | sudo tee /etc/systemd/system/nix-daemon.service.d/corporate-ca.conf >/dev/null
sudo systemctl daemon-reload
sudo systemctl restart nix-daemon

# shellcheck disable=SC1091
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
log "Checking that downloads work"
nix run nixpkgs#hello >/dev/null || die "nix cannot download from the binary cache"

log "Nix is ready. Next: scripts/migrate-to-home-manager.sh"
