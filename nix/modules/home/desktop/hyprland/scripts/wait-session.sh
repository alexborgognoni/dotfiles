for _ in $(seq 1 200); do
  if systemctl --user show-environment | grep -q '^WAYLAND_DISPLAY='; then
    answer="$(gdbus call --session --timeout 3 --dest org.freedesktop.portal.Desktop \
      --object-path /org/freedesktop/portal/desktop \
      --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme 2>/dev/null || true)"
    case "$answer" in
      *"uint32 1"* | *"uint32 2"*) exit 0 ;;
    esac
  fi
  sleep 0.2
done
exit 0
