# Find the running Hyprland when started outside the session
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  # shellcheck disable=SC2012
  HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr" | head -1)"
  export HYPRLAND_INSTANCE_SIGNATURE
fi

# One run at a time: plugging starts several
state="${XDG_RUNTIME_DIR:-/tmp}"
exec 9>"$state/dock-screens.lock"
flock 9

# Identical screens (same model and serial) cannot be told apart by kanshi or
# Hyprland. Their EDIDs differ in the week of manufacture, so: keep the screen
# of the configured week at 0,0 with the internal panel below it, switch the
# other(s) off. Does nothing when everything is already so.
twins=(@twins@)

for ((i = 0; i < ${#twins[@]}; i += 2)); do
  match="${twins[i]}"
  week="${twins[i + 1]}"
  monitors="$(hyprctl monitors all -j)"

  mapfile -t names < <(jq -r --arg m "$match" '.[] | select(.description | contains($m)) | .name' <<<"$monitors")
  [ "${#names[@]}" -ge 2 ] || continue

  keeper=""
  for name in "${names[@]}"; do
    for edid in /sys/class/drm/card*-"$name"/edid; do
      [ -r "$edid" ] || continue
      if [ "$(od -An -tu1 -j16 -N1 "$edid" | tr -d ' ')" = "$week" ]; then keeper="$name"; fi
    done
  done
  [ -n "$keeper" ] || continue

  panel="$(jq -r '[.[] | select(.name | startswith("eDP"))][0].name // empty' <<<"$monitors")"
  height="$(jq -r --arg k "$keeper" '.[] | select(.name == $k) | .height' <<<"$monitors")"
  width="$(jq -r --arg k "$keeper" '.[] | select(.name == $k) | .width' <<<"$monitors")"

  wrong="$(jq -r --arg k "$keeper" --arg m "$match" --arg p "$panel" --argjson h "$height" '
    [ .[] | select(
        (.name == $k and (.disabled or .x != 0 or .y != 0))
        or (.name != $k and (.description | contains($m)) and (.disabled | not))
        or (.name == $p and .y != $h)
      ) ] | length' <<<"$monitors")"
  [ "$wrong" -gt 0 ] || continue

  args=(--output "$keeper" --on --mode "${width}x${height}" --pos "0,0" --scale 1)
  [ -n "$panel" ] && args+=(--output "$panel" --pos "0,$height")
  for name in "${names[@]}"; do
    [ "$name" = "$keeper" ] || args+=(--output "$name" --off)
  done
  wlr-randr "${args[@]}"
done
