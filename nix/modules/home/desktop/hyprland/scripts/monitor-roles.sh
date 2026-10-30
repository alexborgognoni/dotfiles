# Find the running Hyprland when started outside the session (a switch
# from a plain shell, ssh)
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  # shellcheck disable=SC2012
  HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr" | head -1)"
  export HYPRLAND_INSTANCE_SIGNATURE
fi

# One run at a time: every plugged monitor and every new workspace
# starts one
state="${XDG_RUNTIME_DIR:-/tmp}"
exec 9>"$state/monitor-roles.lock"
flock 9

# --force: set the bars even when the layout did not change (Noctalia
# just (re)started or reloaded its config and shows both bars again)
force=false
[ "${1:-}" = "--force" ] && force=true

prefs=(@mainMonitors@)
monitors="$(hyprctl monitors -j)"

main=""
for pref in "${prefs[@]}"; do
  main="$(jq -r --arg p "$pref" '[.[] | select(.description | contains($p))][0].name // empty' <<<"$monitors")"
  [ -n "$main" ] && break
done
if [ -z "$main" ]; then
  main="$(jq -r '([.[] | select(.name | startswith("eDP"))][0] // .[0]).name' <<<"$monitors")"
fi

# Workspaces 1-10 belong on the main display, also those the autostart
# apps fill a moment after login. Only workspaces with windows move:
# moving an empty one makes Hyprland create a replacement at once,
# which ping-pongs endlessly.
workspaces="$(hyprctl workspaces -j)"
for id in $(seq 1 10); do
  current="$(jq -r --argjson id "$id" '.[] | select(.id == $id and .windows > 0) | .monitor' <<<"$workspaces")"
  if [ -n "$current" ] && [ "$current" != "$main" ]; then
    hyprctl dispatch "hl.dsp.workspace.move({ workspace = \"$id\", monitor = \"$main\" })" >/dev/null
  fi
done

# The other displays rest on a high-numbered empty workspace (11, 12,
# ...), not on whichever low number Hyprland picked: otherwise Super+5
# would jump to a side display. The empty low one then disappears.
monitors="$(hyprctl monitors -j)"
workspaces="$(hyprctl workspaces -j)"
focused="$(jq -r '.[] | select(.focused) | .name' <<<"$monitors")"
number=10
switched=false
for name in $(jq -r --arg main "$main" '.[] | select(.name != $main) | .name' <<<"$monitors" | sort); do
  number=$((number + 1))
  active="$(jq -r --arg m "$name" '.[] | select(.name == $m) | .activeWorkspace.id' <<<"$monitors")"
  windows="$(jq -r --argjson id "$active" '.[] | select(.id == $id) | .windows' <<<"$workspaces")"
  if [ "$active" -ge 1 ] && [ "$active" -le 10 ] && [ "${windows:-0}" -eq 0 ]; then
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$name\" })" >/dev/null
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$number\" })" >/dev/null
    switched=true
  fi
done
if $switched; then
  hyprctl dispatch "hl.dsp.focus({ monitor = \"$focused\" })" >/dev/null
fi

layout="$(jq -r --arg main "$main" '.[] | "\(.name) \(if .name == $main then "main" else "basic" end)"' <<<"$monitors" | sort)"
if ! $force && [ -r "$state/monitor-roles" ] && [ "$(cat "$state/monitor-roles")" = "$layout" ]; then
  exit 0
fi
printf '%s\n' "$layout" >"$state/monitor-roles"
rm -f "$state/bars-hidden"
while read -r name role; do
  if [ "$role" = main ]; then show=main hide=basic; else show=basic hide=main; fi
  noctalia msg bar-show "$show" "$name" >/dev/null 2>&1 || true
  noctalia msg bar-hide "$hide" "$name" >/dev/null 2>&1 || true
done <<<"$layout"
