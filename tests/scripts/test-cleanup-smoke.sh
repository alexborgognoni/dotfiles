#!/usr/bin/env bash
# The real cleanup dry run on this machine: read-only, must run through and
# print every section. Skipped where it cannot run (no apt, no installer log).
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"

if ! command -v apt-mark >/dev/null || [ ! -s /var/log/installer/initial-status.gz ]; then
  echo "  skip: not an Ubuntu installation with /var/log/installer/initial-status.gz"
  finish
  exit 0
fi

rc=0
# the exit status of the script, not of the pipe that strips the colors
out="$(env -u LD_LIBRARY_PATH timeout 300 "$repo/scripts/cleanup-ubuntu.sh" 2>&1)" || rc=$?
out="$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')"
assert_eq "$rc" "0" "the dry run exits cleanly"
for section in "apt: packages to remove" "apt: repositories to remove" "snaps to remove" "Homebrew packages to remove" "home: old tools and leftovers" "system: hand installs"; do
  assert_match "$out" "$section" "section: $section"
done
assert_nomatch "$out" "unbound variable|command not found|No such file" "no shell errors in the output"

finish
