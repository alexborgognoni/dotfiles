#!/usr/bin/env bash
# Install Nix (multi-user daemon) on Ubuntu with the official nix-installer,
# ready for corporate TLS inspection (Zscaler): the system CA bundle, which
# already contains the corporate root, is used by the daemon and inside the
# build sandbox. system-manager (nix/modules/system-manager) takes over this
# configuration afterwards. Idempotent; asks for sudo.
set -euo pipefail

ca=/etc/ssl/certs/ca-certificates.crt
user="$(id -un)"
version=2.35.4

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run as your user, not root"
[ -r "$ca" ] || die "missing $ca"
command -v systemctl >/dev/null || die "systemd is required for the Nix daemon"

if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  log "Installing Nix $version (multi-user)"
  installer="$(mktemp)"
  curl -fsSL -o "$installer" "https://github.com/NixOS/nix-installer/releases/download/$version/nix-installer-x86_64-linux"
  chmod +x "$installer"
  sudo "$installer" install linux --no-confirm \
    --ssl-cert-file "$ca" \
    --extra-conf "extra-sandbox-paths = $ca" \
    --extra-conf "trusted-users = root $user"
  rm -f "$installer"
else
  log "Nix is already installed"
fi

# Source fetches in the build sandbox (fetchgit) read the CA from the
# daemon's environment. system-manager manages this file from now on.
dropin=/etc/systemd/system/nix-daemon.service.d/corporate-ca.conf
if [ ! -e "$dropin" ]; then
  log "Configuring the nix-daemon environment"
  sudo mkdir -p "$(dirname "$dropin")"
  printf '[Service]\nEnvironment=NIX_SSL_CERT_FILE=%s\nEnvironment=NIX_GIT_SSL_CAINFO=%s\n' "$ca" "$ca" \
    | sudo tee "$dropin" >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl restart nix-daemon
fi

# shellcheck disable=SC1091
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
log "Checking that downloads work"
nix run nixpkgs#hello >/dev/null || die "nix cannot download from the binary cache"
log "Nix is ready"
