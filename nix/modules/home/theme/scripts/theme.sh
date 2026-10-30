state=@state@
default=@default@

list() { printf '%s\n' @themes@; }
current() { cat "$state/selected" 2>/dev/null || echo "$default"; }

exists() {
  if ! list | grep -x -- "$1" >/dev/null; then
    echo "Unknown theme: $1" >&2
    exit 1
  fi
}

accent_of() {
  if [ -f "$state/accents/$1" ] && [ -e "$state/packs/$1/$(cat "$state/accents/$1")" ]; then
    cat "$state/accents/$1"
  else
    echo default
  fi
}

accents() {
  for d in "$state/packs/$1"/*; do
    name="$(basename "$d")"
    [ "$name" = default ] || echo "$name"
  done
}

# Also runs from the Home Manager activation service, which has no
# session environment: find the runtime dir and Hyprland instance.
uid="$(id -u)"
if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -d "/run/user/$uid" ]; then
  XDG_RUNTIME_DIR="/run/user/$uid"
fi
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/nonexistent}"
# A DISPLAY without a running X server (stale, or no session at all)
# would make the activation's xrdb step fail.
if [ -n "${DISPLAY:-}" ] && [ ! -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; then
  unset DISPLAY
fi
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
  HYPRLAND_INSTANCE_SIGNATURE="$(find "$XDG_RUNTIME_DIR/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' | sort -rn | head -1 | cut -d' ' -f2)"
  export HYPRLAND_INSTANCE_SIGNATURE
fi

# Reload every live consumer in parallel (~100 ms in total).
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
    case "$sock" in *.lock) continue ;; esac
    [ -S "$sock" ] && {
      WAYLAND_DISPLAY="$(basename "$sock")"
      export WAYLAND_DISPLAY
      break
    }
  done
fi

reload_live() {
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
    hyprctl reload >/dev/null 2>&1 &
  fi
  if command -v noctalia >/dev/null; then
    {
      noctalia msg config-reload
      noctalia msg wallpaper-set "$(readlink -f "$state/current/wallpaper")"
    } >/dev/null 2>&1 &
  fi
  for sock in "$XDG_RUNTIME_DIR"/kitty-*; do
    [ -S "$sock" ] || continue
    kitty @ --to "unix:$sock" set-colors --all --configured "$state/current/kitty.conf" >/dev/null 2>&1 &
  done
  if tmux info >/dev/null 2>&1; then
    tmux source-file "$HOME/.config/tmux/theme-reload.conf" >/dev/null 2>&1 &
  fi
  pkill -USR1 -x 'nvim|\.nvim-wrapped' || true
  # Readest rewrites its settings while running; it syncs on start then
  if command -v readest-theme-sync >/dev/null && ! pgrep -x readest >/dev/null; then
    readest-theme-sync >/dev/null 2>&1 &
  fi
  wait
}

# preview <theme> [accent]
preview() {
  exists "$1"
  accent="${2:-$(accent_of "$1")}"
  ln -sfn "$(readlink -f "$state/packs/$1/$accent")" "$state/current.new"
  mv -T "$state/current.new" "$state/current"
  reload_live
}

swatches() {
  theme="$1"
  for a in $(accents "$theme"); do
    hex="$(cut -d' ' -f2 "$state/packs/$theme/$a/accent")"
    r=$((16#${hex:1:2}))
    g=$((16#${hex:3:2}))
    b=$((16#${hex:5:2}))
    printf '\033[38;2;%d;%d;%dm████\033[0m %s\n' "$r" "$g" "$b" "$a"
  done
}

accent_cmd() {
  theme="$(current)"
  case "${1:-pick}" in
    list) accents "$theme" ;;
    pick)
      now="$(accent_of "$theme")"
      [ "$now" = default ] && now="$(cut -d' ' -f1 "$state/packs/$theme/default/accent")"
      start="$(accents "$theme" | grep -nx -- "$now" | cut -d: -f1 || echo 1)"
      choice="$(
        swatches "$theme" | fzf --ansi \
          --prompt '  Accent  ' --pointer '▶' --layout reverse --info hidden \
          --border rounded --border-label " $theme · ↑↓ preview · enter apply · esc cancel " \
          --bind "focus:execute-silent(setsid -f theme preview $theme {2} >/dev/null 2>&1)" \
          --bind 'start:unbind(focus)' \
          --bind "load:pos($start)+rebind(focus)" |
          cut -d' ' -f2
      )" || true
      if [ -n "$choice" ]; then
        accent_cmd "$choice"
      else
        preview "$theme"
      fi
      ;;
    *)
      # No `grep -q`: it exits early and pipefail would report the
      # producer's SIGPIPE as a failure.
      if ! accents "$theme" | grep -x -- "$1" >/dev/null; then
        echo "Unknown accent for $theme: $1 (try: theme accent list)" >&2
        exit 1
      fi
      mkdir -p "$state/accents"
      echo "$1" >"$state/accents/$theme"
      preview "$theme"
      notify-send -a Theme "Accent" "$theme: $1" || true
      ;;
  esac
}

apply() {
  exists "$1"
  echo "$1" >"$state/selected"
  preview "$1"
  base="$(cat "$state/base-generation")"
  if [ "$1" = "$default" ]; then
    "$base/activate" >/dev/null
  else
    "$base/specialisation/$1/activate" >/dev/null
  fi
  reload_live
  notify-send -a Theme "Theme" "Applied $1" || true
}

pick() {
  original="$(current)"
  start="$(list | grep -nx -- "$original" | cut -d: -f1 || echo 1)"
  choice="$(
    list | fzf \
      --prompt '  Theme  ' --pointer '▶' --layout reverse --info hidden \
      --border rounded --border-label ' ↑↓ preview · enter apply · esc cancel ' \
      --bind 'focus:execute-silent(setsid -f theme preview {} >/dev/null 2>&1)' \
      --bind 'start:unbind(focus)' \
      --bind "load:pos($start)+rebind(focus)" \
      --preview "kitten icat --clear --transfer-mode=memory --stdin=no --place=\${FZF_PREVIEW_COLUMNS}x\${FZF_PREVIEW_LINES}@0x0 $state/packs/{}/default/wallpaper" \
      --preview-window 'right,65%,border-left'
  )" || true
  if [ -n "$choice" ]; then
    apply "$choice"
  else
    preview "$original"
  fi
}

wallpaper() {
  case "${1:-}" in
    next) noctalia msg wallpaper-next ;;
    previous) noctalia msg wallpaper-previous ;;
    random) noctalia msg wallpaper-random ;;
    rotate)
      # Noctalia has no config-set IPC; runtime overrides live in
      # settings.toml (like the GUI's), followed by a config reload.
      want="$(@rotate@ "${2:-toggle}")"
      noctalia msg config-reload >/dev/null 2>&1 || true
      notify-send -a Theme "Wallpaper" "Rotation $want" || true
      echo "rotation $want"
      ;;
    *)
      echo "usage: theme wallpaper [next|previous|random|rotate [on|off|toggle]]" >&2
      exit 1
      ;;
  esac
}

case "${1:-pick}" in
  wallpaper)
    shift
    wallpaper "$@"
    ;;
  reload) reload_live ;;
  accent)
    shift
    accent_cmd "$@"
    ;;
  list) list ;;
  current) current ;;
  preview) preview "${2:?usage: theme preview <name>}" ;;
  apply | set) apply "${2:?usage: theme apply <name>}" ;;
  pick) pick ;;
  *)
    echo "usage: theme [pick|list|current|preview <name>|apply <name>|accent ...|wallpaper ...]" >&2
    exit 1
    ;;
esac
