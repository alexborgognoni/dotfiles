# Find the running Hyprland when started outside the session
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  # shellcheck disable=SC2012
  HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr" | head -1)"
  export HYPRLAND_INSTANCE_SIGNATURE
fi

state="${XDG_RUNTIME_DIR:-/tmp}"
roles="$state/monitor-roles"
hidden="$state/bars-hidden"
case "${1:-}" in
  all)
    if [ ! -s "$roles" ]; then
      noctalia msg bar-toggle
    else
      if [ -e "$hidden" ]; then
        action="bar-show"
        rm -f "$hidden"
      else
        action="bar-hide"
        : > "$hidden"
      fi
      while read -r monitor bar; do
        noctalia msg "$action" "$bar" "$monitor"
      done < "$roles"
    fi
    ;;
  focused)
    monitor="$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"
    bar="$(awk -v m="$monitor" '$1 == m { print $2; exit }' "$roles" 2>/dev/null || true)"
    noctalia msg bar-toggle "${bar:-main}" "$monitor"
    ;;
  *)
    echo "usage: toggle-bar all|focused" >&2
    exit 1
    ;;
esac
