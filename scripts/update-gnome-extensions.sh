#!/usr/bin/env bash
# Pin the GNOME Shell extensions (nix/modules/home/gnome/extensions.json):
# for each UUID, the newest version on extensions.gnome.org that supports
# the given shell version, with its download URL and hash. Home Manager
# installs exactly these (nix/modules/home/gnome/default.nix).
#
# Usage: scripts/update-gnome-extensions.sh [shell-version]   (default: 42, Ubuntu 22.04)
# Add or remove an extension: edit the uuids list below, then re-run.
set -euo pipefail

shell="${1:-42}"
out="$(cd "$(dirname "$0")/.." && pwd)/nix/modules/home/gnome/extensions.json"
uuids=(
  AlphabeticalAppGrid@stuarthayhurst
  appindicatorsupport@rgcjonas.gmail.com
  appmenu-color-icon@arahiko-ayami.github.com
  blur-my-shell@aunetx
  clipboard-history@alexsaveau.dev
  emoji-copy@felipeftn
  mprisLabel@moon-0xff.github.com
  notification-banner-reloaded@marcinjakubowski.github.com
  space-bar@luchrioh
  top-bar-organizer@julian.gse.jsts.xyz
  transparent-top-bar@ftpix.com
  unite@hardpixel.eu
  Vitals@CoreCoding.com
)

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
{
  printf '{\n  "shellVersion": "%s",\n  "extensions": [\n' "$shell"
  sep=""
  for uuid in "${uuids[@]}"; do
    info="$(curl -fsS "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$shell")"
    version="$(jq -r .version <<<"$info")"
    url="https://extensions.gnome.org$(jq -r .download_url <<<"$info")"
    hash="sha256-$(curl -fsSL "$url" | openssl dgst -sha256 -binary | base64)"
    printf '%s    {"uuid": "%s", "version": %s, "url": "%s", "hash": "%s"}' "$sep" "$uuid" "$version" "$url" "$hash"
    sep=$',\n'
    echo "$uuid v$version" >&2
  done
  printf '\n  ]\n}\n'
} > "$tmp"
jq . "$tmp" > "$out"
echo "wrote $out" >&2
