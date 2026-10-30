#!/usr/bin/env bash
# list_entries / list_regex: comments, the per-user override, wildcards.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"
# shellcheck source=../../scripts/lib/common.sh
. "$repo/scripts/lib/common.sh"

# work on a fake repository and a fake user config
dotfiles="$tmp/repo"
mkdir -p "$dotfiles/scripts/cleanup.d" "$tmp/config/dotfiles/cleanup.d"
export XDG_CONFIG_HOME="$tmp/config"
cat >"$dotfiles/scripts/cleanup.d/x.list" <<'LIST'
# a comment

alpha
  beta   # inline comment
gamma-*
delta.d
gtk+
LIST

assert_eq "$(list_entries x.list | paste -sd,)" "alpha,beta,gamma-*,delta.d,gtk+" "comments, blanks and whitespace are dropped"
assert_eq "$(list_entries missing.list | wc -l | tr -d ' ')" "0" "a missing list is empty"

# the user's list is added to the shipped one
printf 'epsilon\n# note\n' >"$tmp/config/dotfiles/cleanup.d/x.list"
assert_eq "$(list_entries x.list | paste -sd,)" "alpha,beta,gamma-*,delta.d,gtk+,epsilon" "the per-user list is added"
rm "$tmp/config/dotfiles/cleanup.d/x.list"

re="$(list_regex x.list)"
for yes in alpha beta gamma-1 gamma- delta.d gtk+; do assert_match "$yes" "$re" "matches $yes"; done
for no in alphabet xalpha gamma delta-d deltaxd gtk gtkk "alpha beta"; do assert_nomatch "$no" "$re" "does not match $no"; done

printf 'linux-*\nmesa-[0-9]*\ngnome-[0-9-]*\n' >"$dotfiles/scripts/cleanup.d/y.list"
re="$(list_regex y.list)"
assert_match "linux-image-6.8.0" "$re" "wildcard suffix"
assert_nomatch "mylinux-image" "$re" "anchored at the start"
assert_match "mesa-2404" "$re" "range then wildcard"
assert_nomatch "mesa-abc" "$re" "range must match"
assert_match "gnome-42-2204" "$re" "range with a dash"

: >"$dotfiles/scripts/cleanup.d/empty.list"
assert_nomatch "anything" "$(list_regex empty.list)" "an empty list matches nothing"
assert_nomatch "anything" "$(list_regex missing.list)" "a missing list matches nothing"

finish
