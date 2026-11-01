#!/usr/bin/env bash
# The `theme` command (nix/modules/home/theme/scripts/theme.sh): preview, apply,
# accents, reloads and `theme apps`, with a stub for every program it drives.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"

src="$repo/nix/modules/home/theme/scripts/theme.sh"
state="$tmp/state"
run="$tmp/run"
bin="$tmp/bin"
calls="$tmp/calls"
gen="$tmp/gen"
mkdir -p "$state/packs" "$run" "$bin" "$gen/specialisation"
: >"$calls"

# --- the script, placeholders filled in like theme/command.nix does ----------
printf 'APPLICATION\tHOW\tDETAIL\nkitty\tpack\tkitty.conf\nbat\tstylix\tbat\n' >"$tmp/apps.tsv"
printf '#!/usr/bin/env bash\necho "rotate $*" >> "%s"\necho on\n' "$calls" >"$tmp/rotate"
chmod +x "$tmp/rotate"
sed -e "s|@state@|'$state'|" -e "s|@default@|'macchiato'|" \
  -e "s|@themes@|macchiato nord gruvbox|" -e "s|@rotate@|$tmp/rotate|" \
  -e "s|@apps@|$tmp/apps.tsv|" "$src" >"$tmp/theme"

# --- stubs: log every call -------------------------------------------------
mkstub() {
  printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\n%s\n' "$1" "$calls" "${2:-exit 0}" >"$bin/$1"
  chmod +x "$bin/$1"
}
for p in hyprctl noctalia kitty notify-send pkill; do mkstub "$p"; done
mkstub tmux "exit 1" # no tmux server running

# --- fake packs and generations ------------------------------------------
# make_pack <theme> <accent> <hex> <cursor "name size"> [opacity]
make_pack() {
  d="$state/packs/$1/$2"
  mkdir -p "$d"
  echo "$2 $3" >"$d/accent"
  echo "kitty-$1-$2" >"$d/kitty.conf"
  echo "$4" >"$d/cursor"
  [ -z "${5:-}" ] || echo "$5" >"$d/terminal-opacity"
  : >"$d/wallpaper"
  echo dark >"$d/polarity"
}
make_theme() { # <theme> <cursor> <opacity>
  make_pack "$1" blue '#0000ff' "$2 24" "$3"
  make_pack "$1" peach '#ffaa00' "$2 24" "$3"
  ln -sfn blue "$state/packs/$1/default"
}
make_theme macchiato Macchiato-cursors 0.950000
make_theme nord Nord-cursors 0.900000
make_theme gruvbox Gruvbox-cursors ""
echo "$gen" >"$state/base-generation"
printf '#!/usr/bin/env bash\necho "activate base" >> "%s"\nln -sfn "%s/packs/macchiato/default" "%s/current"\n' "$calls" "$state" "$state" >"$gen/activate"
for t in nord gruvbox; do
  mkdir -p "$gen/specialisation/$t"
  printf '#!/usr/bin/env bash\necho "activate %s" >> "%s"\nln -sfn "%s/packs/%s/default" "%s/current"\n' "$t" "$calls" "$state" "$t" "$state" >"$gen/specialisation/$t/activate"
done
chmod +x "$gen/activate" "$gen"/specialisation/*/activate
ln -sfn "$state/packs/macchiato/default" "$state/current"

# a Hyprland session and a kitty window (a socket file)
mkdir -p "$run/hypr/sig123"
python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$run/kitty-4242" 2>/dev/null ||
  ln -s /dev/null "$run/kitty-4242"
have_socket=0
[ -S "$run/kitty-4242" ] && have_socket=1

# theme <args...>: run the script with the stubs first on PATH, nothing inherited
theme() {
  env -i PATH="$bin:/usr/bin:/bin" HOME="$tmp" XDG_RUNTIME_DIR="$run" \
    bash -o errexit -o nounset -o pipefail "$tmp/theme" "$@"
}
reset_calls() { : >"$calls"; }
line_of() { grep -n -- "$1" "$calls" | head -1 | cut -d: -f1; }

# --- list / current ----------------------------------------------------------
assert_eq "$(theme list | paste -sd,)" "macchiato,nord,gruvbox" "list shows the themes"
assert_eq "$(theme current)" "macchiato" "the default theme is current before anything is applied"

# --- preview: colors and opacity live, no activation, no cursor change --------
reset_calls
theme preview nord
assert_eq "$(readlink -f "$state/current")" "$(readlink -f "$state/packs/nord/blue")" "preview points current at the pack"
[ ! -e "$state/current.new" ] && ok || fail "preview left current.new behind"
assert_eq "$(theme current)" "macchiato" "preview does not change the applied theme"
assert_match "$(cat "$calls")" "hyprctl reload" "preview reloads Hyprland"
assert_match "$(cat "$calls")" "noctalia msg config-reload" "preview reloads Noctalia"
assert_match "$(cat "$calls")" "noctalia msg wallpaper-set $state/packs/nord/blue/wallpaper" "preview sets the wallpaper"
if [ "$have_socket" = 1 ]; then
  assert_match "$(cat "$calls")" "kitty @ --to unix:$run/kitty-4242 set-colors --all --configured $state/current/kitty.conf" "preview recolors kitty"
  assert_match "$(cat "$calls")" "kitty @ --to unix:$run/kitty-4242 set-background-opacity --all 0.900000" "preview sets the terminal opacity of the theme"
fi
assert_nomatch "$(cat "$calls")" "activate" "preview activates nothing"
assert_nomatch "$(cat "$calls")" "setcursor" "preview leaves the cursor alone"

# a pack without a terminal opacity file: colors still apply, opacity untouched
reset_calls
theme preview gruvbox
if [ "$have_socket" = 1 ]; then
  assert_match "$(cat "$calls")" "set-colors" "colors apply without an opacity file"
  assert_nomatch "$(cat "$calls")" "set-background-opacity" "no opacity call without an opacity file"
fi

# --- apply: activation, then the cursor, in that order ----------------------
reset_calls
theme apply nord
assert_eq "$(cat "$state/selected")" "nord" "apply records the theme"
assert_eq "$(theme current)" "nord" "current follows the applied theme"
assert_match "$(cat "$calls")" "activate nord" "apply activates the theme's specialisation"
assert_nomatch "$(cat "$calls")" "activate base" "apply of a non-default theme does not activate the base"
assert_match "$(cat "$calls")" "hyprctl setcursor Nord-cursors 24" "apply switches the cursor"
a="$(line_of 'activate nord')"
c="$(line_of 'setcursor')"
if [ -n "$a" ] && [ -n "$c" ] && [ "$a" -lt "$c" ]; then ok; else fail "the cursor must change after the activation (activate at $a, setcursor at $c)"; fi
assert_match "$(cat "$calls")" "notify-send -a Theme Theme Applied nord" "apply notifies"
last_reload="$(grep -n 'hyprctl reload' "$calls" | tail -1 | cut -d: -f1)"
if [ -n "$last_reload" ] && [ "$last_reload" -gt "$a" ]; then ok; else fail "Hyprland must reload after the activation (activate at $a, last reload at ${last_reload:-none})"; fi

# the default theme is the base generation itself
reset_calls
theme apply macchiato
assert_match "$(cat "$calls")" "activate base" "applying the default activates the base generation"
assert_match "$(cat "$calls")" "hyprctl setcursor Macchiato-cursors 24" "the default theme sets its cursor too"

# --- apply without a compositor, and without hyprctl -----------------------
reset_calls
rm -rf "$run/hypr"
theme apply nord
assert_nomatch "$(cat "$calls")" "hyprctl" "no Hyprland session: hyprctl is never called"
assert_eq "$(cat "$state/selected")" "nord" "the theme is still applied without a session"
mkdir -p "$run/hypr/sig123"
mv "$bin/hyprctl" "$bin/hyprctl.off"
reset_calls
if theme apply gruvbox >/dev/null 2>&1; then ok; else fail "apply must work when hyprctl is not installed"; fi
assert_eq "$(cat "$state/selected")" "gruvbox" "applied without hyprctl"
mv "$bin/hyprctl.off" "$bin/hyprctl"

# a pack without a cursor file: apply still succeeds and changes no cursor
reset_calls
mv "$state/packs/nord/blue/cursor" "$state/packs/nord/blue/cursor.off"
if theme apply nord >/dev/null 2>&1; then ok; else fail "apply must survive a pack without a cursor file"; fi
assert_nomatch "$(cat "$calls")" "setcursor" "no cursor file: no setcursor call"
mv "$state/packs/nord/blue/cursor.off" "$state/packs/nord/blue/cursor"

# --- errors ----------------------------------------------------------------
err="$(theme apply nope 2>&1 || true)"
assert_match "$err" "Unknown theme: nope" "apply rejects an unknown theme"
if theme apply nope >/dev/null 2>&1; then fail "apply of an unknown theme must fail"; else ok; fi
assert_eq "$(cat "$state/selected")" "nord" "a failed apply leaves the selection alone"
if theme preview nope >/dev/null 2>&1; then fail "preview of an unknown theme must fail"; else ok; fi
if theme apply >/dev/null 2>&1; then fail "apply without a name must fail"; else ok; fi
if theme preview >/dev/null 2>&1; then fail "preview without a name must fail"; else ok; fi
err="$(theme frobnicate 2>&1 || true)"
assert_match "$err" "usage: theme" "an unknown command prints the usage"
assert_match "$err" "apps" "the usage mentions apps"

# --- accents ---------------------------------------------------------------
reset_calls
theme apply nord
assert_eq "$(theme accent list | paste -sd,)" "blue,peach" "accent list: every accent but 'default'"
theme accent peach
assert_eq "$(cat "$state/accents/nord")" "peach" "the accent is remembered per theme"
assert_eq "$(readlink -f "$state/current")" "$(readlink -f "$state/packs/nord/peach")" "the accent switches the live pack"
err="$(theme accent chartreuse 2>&1 || true)"
assert_match "$err" "Unknown accent for nord: chartreuse" "an unknown accent is rejected"
assert_eq "$(cat "$state/accents/nord")" "peach" "a rejected accent changes nothing"
# a remembered accent that no longer exists falls back to the default
echo vanished >"$state/accents/nord"
theme preview nord
assert_eq "$(readlink -f "$state/current")" "$(readlink -f "$state/packs/nord/default")" "a vanished accent falls back to the default pack"
rm -f "$state/accents/nord"

# --- apps --------------------------------------------------------------------
if command -v column >/dev/null 2>&1; then
  out="$(theme apps)"
  assert_match "$out" "^APPLICATION +HOW +DETAIL" "apps prints a header"
  assert_match "$out" "kitty +pack +kitty.conf" "apps lists an application with how and detail"
  assert_match "$out" "bat +stylix +bat" "apps lists every row"
fi

# --- wallpaper subcommands -------------------------------------------------
reset_calls
theme wallpaper next
assert_match "$(cat "$calls")" "noctalia msg wallpaper-next" "wallpaper next"
reset_calls
out="$(theme wallpaper rotate toggle)"
assert_match "$out" "rotation on" "wallpaper rotate reports the new state"
assert_match "$(cat "$calls")" "rotate toggle" "wallpaper rotate passes the mode on"
if theme wallpaper sideways >/dev/null 2>&1; then fail "a bad wallpaper command must fail"; else ok; fi

finish
