# The pinned plugins: source revision, id, panels, tools, settings and the bar
# widgets each brings (see plugins.nix for how a revision is chosen).
{ config, pkgs }:
let
  inherit (pkgs) lib;

  # Panels opened by a key open in the centre of the screen
  centred =
    panels:
    lib.listToAttrs (
      lib.concatMap (panel: [
        (lib.nameValuePair "${panel}_position" "center")
        (lib.nameValuePair "${panel}_open_near_click" false)
      ]) panels
    );

  # What gamer mode pauses (SIGSTOP, resumed when it ends): user-level programs
  # only. The plugin's own list stops system services through pkexec and, in
  # "heavy", also freezes language servers; this one touches nothing that needs
  # root. A frozen program keeps its state but its network connections drop
  # (so "heavy", which includes the browsers, pauses Teams and Outlook too).
  # Names are what `pgrep -x` sees: the command name, cut at 15 characters
  # (Nix wraps Firefox, hence the odd one).
  freeze =
    profiles: names:
    map (match: {
      inherit match profiles;
      kind = "process";
      action = "freeze";
    }) names;
  gamerTargets =
    freeze
      [ "light" "heavy" ]
      [
        "syncthing"
        "onedrive"
        "dropbox"
        "nextcloud"
        "qbittorrent"
        "tracker-miner-f"
        "tracker-extract"
      ]
    ++
      freeze
        [ "heavy" ]
        [
          "chrome"
          "msedge"
          "firefox"
          ".firefox-wrappe"
          "code"
          "obsidian"
        ];

  fetch =
    {
      repo,
      rev,
      dir,
      hash,
    }:
    pkgs.fetchFromGitHub {
      owner = "noctalia-dev";
      inherit repo rev hash;
      sparseCheckout = [ dir ];
    };

  # nvtop's panel runs its helper scripts with `python3` and needs Pillow for
  # the gauges
  nvtopPython = pkgs.python3.withPackages (ps: [ ps.pillow ]);

in
{
  airpods = {
    src = fetch {
      repo = "community-plugins";
      rev = "cd454463cdafa8684e7e886fd9bd9bc99b51b462";
      dir = "airpods";
      hash = "sha256-Adjbij+tJaPliawQtp0yXaQQiBSEVh5AmLC6Slbfikg=";
    };
    id = "harveywuk/airpods";
    panels = [ "panel" ];
    # The bar widget draws only the icon; add one thin bar per earbud (green,
    # red when low). The exact levels are in the tooltip. A headset gets one.
    patch = ''
      substituteInPlace airpods/widget.luau \
        --replace-fail 'barWidget.render(container({ gap = 5, align = "center" }, children))' '
      if hasAirPods and not barWidget.isVertical() then
        local function bar(level)
          local known = type(level) == "number" and level >= 0
          local value = known and level or 0
          return ui.progress({
            progress = value / 100,
            fill = value <= 20 and "error" or "#a6e3a1",
            track = "on_surface/0.2",
            radius = 2,
            width = 24,
            height = 4,
            opacity = known and 1 or 0.4,
          })
        end
        if snapshot.isHeadset == true then
          table.insert(children, bar(snapshot.headset and snapshot.headset.level))
        else
          table.insert(children, ui.column({ gap = 3, align = "center" }, {
            bar(snapshot.left and snapshot.left.level),
            bar(snapshot.right and snapshot.right.level),
          }))
        end
      end
      barWidget.render(container({ gap = 5, align = "center" }, children))'
    '';
  };

  bitwarden = {
    src = fetch {
      repo = "official-plugins";
      rev = "d696743c5e6718ed5bf6b4a4ef10d2636002d80c";
      dir = "bitwarden";
      hash = "sha256-hOiHXnSYD2g8coSN2N5S01t2lvow/xGlsVRfUXXDcbg=";
    };
    id = "noctalia/bitwarden";
    panels = [
      "unlock"
      "login"
      "fields"
    ];
    packages = [
      pkgs.unstable.bitwarden-cli
      pkgs.wtype # the field picker's Autotype button
    ];
    settings = {
      vault_timeout = "30";
      clear_clipboard_seconds = 45;
    };
  };

  # Pick a color anywhere on the screen (click the bar icon; right click picks
  # straight to the clipboard). v1.0.7 is the newest release plugin API 39
  # (Noctalia 5.4) can load; v2.0 needs 43. hyprpicker brings wl-clipboard.
  color_picker = {
    src = fetch {
      repo = "community-plugins";
      rev = "f05b3e45e59b9128834330036ac93efb61af00a4";
      dir = "color_picker";
      hash = "sha256-DK3XVBmv3uLZoWlPMlvrQLuHOJ2MWJMpGzi6pmxmons=";
    };
    id = "oldirtty/color_picker";
    panels = [ "panel" ];
    packages = [ pkgs.unstable.hyprpicker ];
    widget.color-picker.type = "oldirtty/color_picker:widget";
  };

  # Dictation state in the bar (microphone: idle, recording, transcribing);
  # click starts or stops a recording, right click stops it. Talks to the
  # `voxtype` daemon (modules/home/desktop/voxtype.nix). Plugin API 14.
  voxtype = {
    src = fetch {
      repo = "community-plugins";
      rev = "95595088d9bb36a0216d873592fab08cddee2b75";
      dir = "voxtype";
      hash = "sha256-jS8yEtA08iAVB1KAyCMQb1euEuP4DGRkHfu+gnZRHr4=";
    };
    id = "gabedunn/voxtype";
    # idle is a plain microphone (the default, a crossed-out one, reads as muted)
    widget.voxtype = {
      type = "gabedunn/voxtype:status";
      idle_glyph = "microphone-2";
    };
  };

  # Emoji and symbols with search, categories and "frequently used" (Super+.).
  # v1.2.1 is the newest release plugin API 39 can load. Its dataset only has
  # emoji and symbols: the patch adds the Latin letters of other layouts (ä ö ü
  # ß é è ç œ ñ ..., German and French first) and the quotation marks of those
  # languages, searchable as "a umlaut", "e acute", "sharp s", "guillemet".
  emoji-picker = {
    src = fetch {
      repo = "community-plugins";
      rev = "1ef3097060a9200fee0ab70bd0217720d5d9e055";
      dir = "emoji-picker";
      hash = "sha256-Q22AqYH/ODUGBHFhwzobVfXi2RtPOjKzWg7coXu+/XE=";
    };
    id = "liamwh/emoji-picker";
    panels = [
      "wide"
      "desktop"
      "compact"
    ];
    settings = centred [
      "wide"
      "desktop"
      "compact"
    ];
    patch = ''
      ${pkgs.python3}/bin/python3 ${./plugin-patches/latin-letters.py} emoji-picker/assets/emoji.json
    '';
  };

  # Quick notes as plain text files (~/Documents/Notes, markdown: yours to edit
  # elsewhere, grep or keep in git). Written from the launcher: `/nt buy milk`
  # adds to the scratchpad, bare `/nt` lists the notes. No bar widget and no
  # key on purpose.
  notes = {
    src = fetch {
      repo = "official-plugins";
      rev = "9e8da3201aed794fce6b9f3bc7422c8b35e0bcd0";
      dir = "notes";
      hash = "sha256-r7dfOaukzjZvrpAJR9BF1hZn9n13yESZZjzBq+CxYoM=";
    };
    id = "noctalia/notes";
    panels = [ "panel" ];
    # a full-height side panel, as designed (not next to a click)
    settings = {
      panel_position = "center_right";
      panel_open_near_click = false;
    };
  };

  # CUPS in the bar: appears when a job is queued or a printer stops (system
  # CUPS: lpstat, lp, cancel, lpoptions, lpadmin).
  printers = {
    src = fetch {
      repo = "community-plugins";
      rev = "cbb7dd2fc90ad792b02cd2926c2f05471dffe7c1";
      dir = "printers";
      hash = "sha256-fC5yGzXx5V1EkdAZH4Tpuj8FBXT9SurwHXwE9A+jE98=";
    };
    id = "andrewdems/printers";
    panels = [ "panel" ];
    widget.printer.type = "andrewdems/printers:printer";
  };

  # One click: the power profile goes to performance and background programs
  # are paused (gamerTargets above), everything is restored when it ends. Only
  # the toggle is in the bar: the resource readings are the stats pill's job.
  # Needs pgrep, pkill and powerprofilesctl.
  gamer-mode = {
    src = fetch {
      repo = "community-plugins";
      rev = "12e0501c445c2bd44033e31b7e4b5feeec76ba55";
      dir = "gamer-mode";
      hash = "sha256-oUBIKK5vZgNIJbEAUbihqbDsYRg2Ej8VpSQjI6JvAzk=";
    };
    id = "nomadcxx/gamer-mode";
    panels = [ "main" ];
    settings.targets = builtins.toJSON gamerTargets;
    widget.gamermode.type = "nomadcxx/gamer-mode:gamermode";
  };

  file-search = {
    src = fetch {
      repo = "community-plugins";
      rev = "c395ed20913218df9be45d466c66f38070cd1b47";
      dir = "file-search";
      hash = "sha256-hSp62lH4UWgYAnDgGUIHlVWSKFxfoS7t8nRWWNr0pkc=";
    };
    id = "nightwatch75/file-search";
    panels = [ "panel" ];
    settings.exclude_dirs = ".git, node_modules, .cache, .venv, .npm, .cargo, .rustup, .local, .mozilla, .var, snap";
  };

  keybind-cheatsheet = {
    src = fetch {
      repo = "community-plugins";
      rev = "56aa1be46605554222e061d34ad475d4949bf2bf";
      dir = "keybind-cheatsheet";
      hash = "sha256-pqTRx70iZd1zbi4SAuiMfFyrgw6+DUfyELkkSjxnxi0=";
    };
    id = "kenn/keybind-cheatsheet";
    panels = [ "cheatsheet" ];
    widget.keybinds.type = "kenn/keybind-cheatsheet:keybinds";
    settings = {
      hyprland_lua_config = "${config.xdg.configHome}/hypr/hyprland.lua";
      show_undescribed = false;
      # Super+F1 and the bar widget open it the same way: centred
      cheatsheet_position = "center";
      cheatsheet_open_near_click = false;
    };
  };

  pomodoro = {
    src = fetch {
      repo = "community-plugins";
      rev = "cd454463cdafa8684e7e886fd9bd9bc99b51b462";
      dir = "pomodoro";
      hash = "sha256-SWLHPzbj4pZnnz+VmuLhnx+K4sCJXGIHcJ+IKb8uyQ0=";
    };
    id = "thepunkoff/pomodoro";
    panels = [ "panel" ];
    widget.pomodoro.type = "thepunkoff/pomodoro:widget";
  };

  # Displays (resolution, refresh rate, scale, rotation, order), input and
  # look, with a 15 s keep-or-revert. Needs Hyprland 0.56+ and the Lua it is
  # built against; v1.0.0 is the newest release plugin API 32 (Noctalia 5.4)
  # can load. Its changes go to ~/.config/hypr/hyprland-settings.lua, which
  # hyprland/settings-panel.nix loads it last.
  hyprland-settings = {
    src = fetch {
      repo = "community-plugins";
      rev = "5e72a6e85b64137cf620f0946160a186f4e67761";
      dir = "hyprland-settings";
      hash = "sha256-Ig9dMIqJlav2Ooef0ljbitWfXZYaalSFjEsiov0PABI=";
    };
    id = "michael-retunzew/hyprland-settings";
    panels = [ "panel" ];
    packages = [ pkgs.unstable.lua5_5 ];
    settings = {
      panel_position = "center";
      panel_open_near_click = false;
    };
    widget.hypr-settings.type = "michael-retunzew/hyprland-settings:button";
  };

  nvtop = {
    src = fetch {
      repo = "community-plugins";
      rev = "1543628d5c1a1c52be8392c71dbe286dd43e25aa";
      dir = "nvtop";
      hash = "sha256-tedc4uJOPSmNkmzv1WC+9KOsWCSmAEAJpduK+Krpbsw=";
    };
    id = "tordex/nvtop";
    panels = [ "panel" ];
    # The plugin's own widget is a static icon (it only runs nvtop while its
    # panel is open). The built-in system monitor shows the live value, and
    # a click opens the panel sorted by GPU load (load) or memory (VRAM).
    widget.gpu = {
      type = "sysmon";
      stat = "gpu_usage";
      visualization = "none";
      label_min_width = 36.0;
      actions.left = "panel-toggle tordex/nvtop:panel gpu";
    };
    widget.gpu-vram = {
      type = "sysmon";
      stat = "gpu_vram";
      visualization = "none";
      label_min_width = 36.0;
      actions.left = "panel-toggle tordex/nvtop:panel mem";
    };
    # NVIDIA only: the plugin needs VRAM figures, which an integrated GPU
    # (listed first by the full build) does not report, and it crashes on them
    packages = [ pkgs.unstable.nvtopPackages.nvidia ];
    patch = ''
      substituteInPlace nvtop/panel.luau \
        --replace-fail '"python3 "' '"${nvtopPython}/bin/python3 "'
    '';
  };
}
