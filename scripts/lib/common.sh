# shellcheck shell=bash
# Shared by the scripts in this directory:
#   . "$(dirname "$0")/lib/common.sh"
# Sets `dotfiles` (the repository root) and provides the helpers below.

dotfiles="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
item() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- cleanup lists ---------------------------------------------------------
# Plain-text lists in scripts/cleanup.d/, one entry per line, "#" comments.
# A list of the same name in ~/.config/dotfiles/cleanup.d/ is added to it, so
# one machine (or one coworker) can extend them without touching the repo.

# list_entries <name>: the entries of both files
list_entries() {
  local f
  for f in "$dotfiles/scripts/cleanup.d/$1" "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/cleanup.d/$1"; do
    [ -r "$f" ] && sed -E 's/[[:space:]]*#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//; /^$/d' "$f"
  done
  return 0
}

# list_regex <name>: ERE matching a whole name; "*" is a wildcard, "[0-9]"
# style ranges work. Matches nothing when the list is empty.
list_regex() {
  local entries
  entries="$(list_entries "$1" | sed -E 's/\./\\./g; s/\+/\\+/g; s/\*/.*/g' | paste -sd'|')"
  if [ -n "$entries" ]; then printf '^(%s)$' "$entries"; else printf '^$a'; fi
}

# --- apt ---------------------------------------------------------------------
# origin_foreign <package>...: the packages whose installed version does not
# come from Ubuntu's archive: vendor repositories (corporate agents, Docker,
# Edge, ...) and local .debs. Reads apt-cache policy: the first source listed
# for the installed version is the one apt would use.
origin_foreign() {
  [ "$#" -gt 0 ] || return 0
  apt-cache policy "$@" 2>/dev/null | awk '
    /^[^ ].*:$/ { pkg = substr($0, 1, length($0) - 1); installed = 0; next }
    /\*\*\*/ { installed = 1; next }
    installed && /^ +[0-9]+ / {
      if ($2 !~ /^https?:\/\/[A-Za-z0-9.-]*ubuntu\.com\//) print pkg
      installed = 0
    }'
}
