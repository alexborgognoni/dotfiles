# Find the running Hyprland when started outside the session
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  # shellcheck disable=SC2012
  HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr" | head -1)"
  export HYPRLAND_INSTANCE_SIGNATURE
fi

main="$(awk '$2 == "main" { print $1; exit }' "${XDG_RUNTIME_DIR:-/tmp}/monitor-roles" 2>/dev/null || true)"
if [ -n "$main" ]; then
  hyprctl dispatch "hl.dsp.focus({ monitor = \"$main\" })" >/dev/null
fi
hyprctl dispatch "hl.dsp.focus({ workspace = \"$1\" })" >/dev/null
