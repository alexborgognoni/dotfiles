# Theme switching with live preview.
#
#   ~/.local/state/theme/
#     packs           -> every theme's packs: packs/<theme>/<accent>/
#     current         -> the pack that live programs read right now
#     selected        the applied theme (survives rebuilds)
#     accents/<theme> the accent chosen for a theme (else its default)
#
# kitty, tmux, Neovim, Hyprland and Noctalia read their colors through
# `current`, so pointing it at another pack and reloading them is instant;
# that is what hovering in the picker does. Applying a theme also activates
# its pre-built Home Manager specialisation, which re-themes everything else
# (GTK, Qt, Firefox, fonts, cursor, icons, ...). The default theme is the base
# generation itself.
#
#   theme                 open the picker (Super+T)
#   theme apply <name>    switch theme
#   theme preview <name>  live-preview without applying
#   theme accent          pick the accent color of the current theme (Super+Shift+T)
#   theme accent <color>  set it directly; `theme accent list` lists them
#   theme list | current
#   theme wallpaper next|previous|random|rotate [on|off|toggle]
{
  config,
  inputs,
  lib,
  pkgs,
  themeCatalogue,
  ...
}:
let
  # Built once per pkgs and passed in as a special argument, so the theme
  # specialisations don't re-evaluate it.
  catalogue = themeCatalogue;
  features = config.my.features;
  # Stylix themes everything (GTK, Qt, ...) only with the desktop feature and
  # toolkit theming; otherwise just the terminal-side programs.
  themeEverything = features.desktop.enable && config.my.desktop.themeToolkits;
  inherit (catalogue) themes packs;
  cfg = config.my.theme;

  # Themes with a pre-built specialisation (plus the default theme).
  prebuilt = config.my.themes.prebuilt;
  available = lib.filterAttrs (
    name: _: name == catalogue.default || prebuilt == null || lib.elem name prebuilt
  ) themes;
  stateDir = "${config.xdg.stateHome}/theme";

  # theme wallpaper rotate on|off|toggle -> prints the new state
  rotateScript =
    pkgs.writers.writePython3 "theme-wallpaper-rotate"
      {
        libraries = [ pkgs.python3Packages.tomli-w ];
      }
      ''
        import os
        import sys
        import tomllib
        from pathlib import Path

        import tomli_w

        state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
        config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
        settings_file = state / "noctalia" / "settings.toml"


        def load(path):
            try:
                return tomllib.loads(path.read_text())
            except FileNotFoundError:
                return {}


        def enabled(data):
            return data.get("wallpaper", {}).get("automation", {}).get("enabled")


        settings = load(settings_file)
        current = enabled(settings)
        if current is None:
            current = bool(enabled(load(config / "noctalia" / "config.toml")))

        mode = sys.argv[1] if len(sys.argv) > 1 else "toggle"
        if mode not in ("on", "off", "toggle"):
            sys.exit("usage: theme wallpaper rotate [on|off|toggle]")
        want = {"on": True, "off": False, "toggle": not current}[mode]

        automation = settings.setdefault("wallpaper", {}).setdefault("automation", {})
        automation["enabled"] = want
        settings_file.parent.mkdir(parents=True, exist_ok=True)
        settings_file.write_text(tomli_w.dumps(settings))
        print("on" if want else "off")
      '';

  themeCommand = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs =
      with pkgs;
      [
        coreutils
        util-linux
        gnugrep
        procps
        findutils
        fzf
        libnotify
        tmux
      ]
      # Explicit, so reloads also work from the activation service's bare PATH.
      ++ lib.optional features.gui.enable config.programs.kitty.package
      ++ lib.optionals features.desktop.enable [
        pkgs.unstable.hyprland
        config.programs.noctalia.package
      ];
    text = ''
      state=${lib.escapeShellArg stateDir}
      default=${lib.escapeShellArg catalogue.default}

      list() { printf '%s\n' ${lib.escapeShellArgs (lib.attrNames available)}; }
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
      if [ -z "''${XDG_RUNTIME_DIR:-}" ] && [ -d "/run/user/$uid" ]; then
        XDG_RUNTIME_DIR="/run/user/$uid"
      fi
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/nonexistent}"
      # A DISPLAY without a running X server (stale, or no session at all)
      # would make the activation's xrdb step fail.
      if [ -n "''${DISPLAY:-}" ] && [ ! -S "/tmp/.X11-unix/X''${DISPLAY#*:}" ]; then
        unset DISPLAY
      fi
      if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
        HYPRLAND_INSTANCE_SIGNATURE="$(find "$XDG_RUNTIME_DIR/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' | sort -rn | head -1 | cut -d' ' -f2)"
        export HYPRLAND_INSTANCE_SIGNATURE
      fi

      # Reload every live consumer in parallel (~100 ms in total).
      if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
          case "$sock" in *.lock) continue ;; esac
          [ -S "$sock" ] && { WAYLAND_DISPLAY="$(basename "$sock")"; export WAYLAND_DISPLAY; break; }
        done
      fi

      reload_live() {
        if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
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
        accent="''${2:-$(accent_of "$1")}"
        ln -sfn "$(readlink -f "$state/packs/$1/$accent")" "$state/current.new"
        mv -T "$state/current.new" "$state/current"
        reload_live
      }

      swatches() {
        theme="$1"
        for a in $(accents "$theme"); do
          hex="$(cut -d' ' -f2 "$state/packs/$theme/$a/accent")"
          r=$((16#''${hex:1:2})); g=$((16#''${hex:3:2})); b=$((16#''${hex:5:2}))
          printf '\033[38;2;%d;%d;%dm████\033[0m %s\n' "$r" "$g" "$b" "$a"
        done
      }

      accent_cmd() {
        theme="$(current)"
        case "''${1:-pick}" in
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
            echo "$1" > "$state/accents/$theme"
            preview "$theme"
            notify-send -a Theme "Accent" "$theme: $1" || true
            ;;
        esac
      }

      apply() {
        exists "$1"
        echo "$1" > "$state/selected"
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
            --preview "kitten icat --clear --transfer-mode=memory --stdin=no --place=\''${FZF_PREVIEW_COLUMNS}x\''${FZF_PREVIEW_LINES}@0x0 $state/packs/{}/default/wallpaper" \
            --preview-window 'right,65%,border-left'
        )" || true
        if [ -n "$choice" ]; then
          apply "$choice"
        else
          preview "$original"
        fi
      }

      wallpaper() {
        case "''${1:-}" in
          next) noctalia msg wallpaper-next ;;
          previous) noctalia msg wallpaper-previous ;;
          random) noctalia msg wallpaper-random ;;
          rotate)
            # Noctalia 5.12 has no config-set IPC; runtime overrides live in
            # settings.toml (like the GUI's), followed by a config reload.
            want="$(${rotateScript} "''${2:-toggle}")"
            noctalia msg config-reload >/dev/null 2>&1 || true
            notify-send -a Theme "Wallpaper" "Rotation $want" || true
            echo "rotation $want"
            ;;
          *) echo "usage: theme wallpaper [next|previous|random|rotate [on|off|toggle]]" >&2; exit 1 ;;
        esac
      }

      case "''${1:-pick}" in
        wallpaper) shift; wallpaper "$@" ;;
        reload) reload_live ;;
        accent) shift; accent_cmd "$@" ;;
        list) list ;;
        current) current ;;
        preview) preview "''${2:?usage: theme preview <name>}" ;;
        apply | set) apply "''${2:?usage: theme apply <name>}" ;;
        pick) pick ;;
        *)
          echo "usage: theme [pick|list|current|preview <name>|apply <name>|accent ...|wallpaper ...]" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  options.my.theme = lib.mkOption {
    type = lib.types.raw;
    default = themes.${catalogue.default};
    description = "The theme of this generation (see themes/default.nix).";
  };

  options.my.themes.prebuilt = lib.mkOption {
    type = lib.types.nullOr (lib.types.listOf (lib.types.enum (lib.attrNames themes)));
    default = null;
    example = [
      "nord"
      "dracula"
    ];
    description = ''
      Themes that get a pre-built specialisation (the default theme always
      does); null builds all of them. Fewer themes mean faster rebuilds and
      less evaluation memory.
    '';
  };

  options.my.isThemeSpecialisation = lib.mkOption {
    type = lib.types.bool;
    default = false;
    internal = true;
  };

  options.my.themeState = lib.mkOption {
    type = lib.types.str;
    default = stateDir;
    readOnly = true;
    description = "Directory holding the live theme state (`current` points at the active pack).";
  };

  imports = [ inputs.stylix.homeModules.stylix ];

  config = lib.mkMerge [
    {
      home.packages = [ themeCommand ];

      # Stylix follows this generation's theme (specialisations override
      # my.theme). Without the desktop feature (e.g. Ubuntu with GNOME) only
      # terminal-side programs are themed, not GTK/Qt or the desktop.
      stylix = lib.mkMerge [
        (
          catalogue.toStylix cfg
          // {
            enable = true;
            autoEnable = themeEverything;
          }
        )
        {
          targets.hyprpaper.enable = false;
          # Stylix enables Qt by itself only under NixOS
          targets.qt.enable = themeEverything;
          # Package overlays belong to the package set's owner (NixOS Stylix
          # or nothing); with useGlobalPkgs Home Manager must not add any.
          overlays.enable = false;
        }
        (lib.mkIf (!themeEverything) {
          targets = {
            bat.enable = true;
            btop.enable = true;
            fzf.enable = true;
            lazygit.enable = true;
            yazi.enable = true;
            starship.enable = true;
            kitty.enable = features.gui.enable;
            firefox.enable = features.gui.enable;
          };
        })
      ];

      # Every generation points `current` at its own theme's pack, using the
      # accent the user picked for that theme.
      home.activation.themePack = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        themeState=${lib.escapeShellArg stateDir}
        run mkdir -p "$themeState/accents"
        run ln -sfn ${packs} "$themeState/packs"
        themeAccent=default
        if [ -f "$themeState/accents/${cfg.name}" ] \
          && [ -e "${cfg.packDir}/$(cat "$themeState/accents/${cfg.name}")" ]; then
          themeAccent="$(cat "$themeState/accents/${cfg.name}")"
        fi
        run ln -sfn "$(readlink -f "${cfg.packDir}/$themeAccent")" "$themeState/current"
      '';

      # Let running programs pick up the (possibly new) pack.
      home.activation.themeReload =
        lib.hm.dag.entryAfter [ "themePack" "onFilesChange" "themeRestore" ]
          ''
            run ${themeCommand}/bin/theme reload || true
          '';

    }

    (lib.mkIf (!config.my.isThemeSpecialisation) {
      specialisation = lib.mapAttrs (_: theme: {
        configuration = {
          my.theme = lib.mkForce theme;
          my.isThemeSpecialisation = true;
        };
      }) (lib.removeAttrs available [ catalogue.default ]);

      home.activation = {
        themeBaseGeneration = lib.hm.dag.entryAfter [ "themePack" ] ''
          run --quiet sh -c 'echo "$1" > "$2"' _ "$newGenPath" ${lib.escapeShellArg stateDir}/base-generation
        '';

        # A rebuild activates the base (default) theme; re-apply the user's choice.
        themeRestore = lib.hm.dag.entryAfter [ "themeBaseGeneration" "reloadSystemd" "onFilesChange" ] ''
          selected=${lib.escapeShellArg stateDir}/selected
          if [ -f "$selected" ]; then
            themeName="$(cat "$selected")"
            if [ "$themeName" != ${lib.escapeShellArg catalogue.default} ] \
              && [ -x "$newGenPath/specialisation/$themeName/activate" ]; then
              verboseEcho "Restoring theme $themeName"
              run "$newGenPath/specialisation/$themeName/activate"
            fi
          fi
        '';
      };
    })
  ];
}
