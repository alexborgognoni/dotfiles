#!/usr/bin/env bash
# The apt layer of an Ubuntu machine: what Nix cannot provide there (root
# daemons tied to the distribution, the login shell). Plain data in apt/:
#   packages.list      apt packages
#   repos/<name>.list  third-party repository (@RELEASE@ = the Ubuntu release);
#                      its key is keys/<name>.asc, installed in /etc/apt/keyrings
#   vendor-debs.list   "<package> <url>": installed from a .deb when missing
# ~/.config/dotfiles/apt/<same name> adds entries for one machine. Idempotent:
# a machine that is up to date needs no network and changes nothing.
#
#   scripts/apt-layer.sh --check     what would change (changes nothing, no root);
#                                    exits 1 when something is pending
#   sudo scripts/apt-layer.sh        apply it
#   --user NAME                      whose groups and login shell (default: the
#                                    user who ran sudo)
set -euo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

# --- what else is set up ---------------------------------------------------------
groups=(docker libvirt) # the user joins them (the packages above create them)
login_shell=/usr/bin/zsh
# ----------------------------------------------------------------------------------

check=false
target_user="${SUDO_USER:-$(id -un)}"
while [ $# -gt 0 ]; do
  case "$1" in
    --check) check=true ;;
    --user)
      shift
      target_user="${1:?--user needs a name}"
      ;;
    *) die "usage: apt-layer.sh [--check] [--user NAME]" ;;
  esac
  shift
done
[ "$target_user" != root ] || die "run it with sudo from your own account (or --user NAME): not for root"
$check || [ "$(id -u)" -eq 0 ] || die "run it with sudo (or use --check)"

root="${APT_LAYER_ROOT:-}" # a prefix for /etc, for the tests
# shellcheck disable=SC1091
release="$(. "$root/etc/os-release" && echo "$VERSION_CODENAME")"
log "apt layer for $target_user on $release$($check && echo ' (check only)')"

pending=0
# act "<what>" command...: do it, or only say so with --check
act() {
  local what="$1"
  shift
  pending=$((pending + 1))
  if $check; then
    item "would: $what"
  else
    item "$what"
    "$@"
  fi
}

write_file() { # <content> <path>
  mkdir -p "$(dirname "$2")"
  printf '%s\n' "$1" >"$2"
  chmod 0644 "$2"
}
# (a package on hold reads "hold ok installed": still installed)
installed() { [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == *" ok installed" ]]; }
apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# --- repositories -------------------------------------------------------------------
for list in "$dotfiles"/apt/repos/*.list; do
  [ -e "$list" ] || continue
  name="$(basename "$list" .list)"
  key="$dotfiles/apt/keys/$name.asc"
  [ -f "$key" ] || die "apt/keys/$name.asc is missing (the key of apt/repos/$name.list)"
  keyring="$root/etc/apt/keyrings/$name.asc"
  target="$root/etc/apt/sources.list.d/$name.list"
  want="$(sed "s/@RELEASE@/$release/g" "$list")"
  cmp -s "$key" "$keyring" 2>/dev/null ||
    act "install the $name repository key ($keyring)" install -D -m 0644 "$key" "$keyring"
  [ "$(entries_of "$target")" = "$(normalize <<<"$want")" ] ||
    act "write the $name repository ($target)" write_file "$want" "$target"
done

# --- packages -------------------------------------------------------------------------
missing=()
while IFS= read -r package; do
  installed "$package" || missing+=("$package")
done < <(apt_entries packages.list)
if [ "${#missing[@]}" -gt 0 ]; then
  act "install ${#missing[@]} package(s): ${missing[*]}" bash -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"' _ "${missing[@]}"
fi

# --- vendor packages ---------------------------------------------------------------------
install_deb() { # <package> <url>
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$2" -o "$tmp/$1.deb"
  apt_install "$tmp/$1.deb"
  rm -rf "$tmp"
}
while read -r package url; do
  [ -n "$package" ] || continue
  installed "$package" || act "install $package from $url" install_deb "$package" "$url"
done < <(apt_entries vendor-debs.list)

# --- the user --------------------------------------------------------------------------------
user_groups="$(id -nG "$target_user" 2>/dev/null | tr ' ' '\n')"
for group in "${groups[@]}"; do
  grep -qx "$group" <<<"$user_groups" && continue
  if ! $check && ! getent group "$group" >/dev/null; then
    warn "no group $group (is its package in apt/packages.list?)"
    continue
  fi
  act "add $target_user to the $group group" usermod -aG "$group" "$target_user"
done
current_shell="$(getent passwd "$target_user" | cut -d: -f7)"
[ "$current_shell" = "$login_shell" ] ||
  act "login shell of $target_user: $login_shell (now ${current_shell:-unknown})" chsh -s "$login_shell" "$target_user"

# --- result -------------------------------------------------------------------------------------
if [ "$pending" -eq 0 ]; then
  log "apt layer: nothing to do"
elif $check; then
  log "apt layer: $pending change(s) pending"
  exit 1
else
  log "apt layer: $pending change(s) applied"
fi
