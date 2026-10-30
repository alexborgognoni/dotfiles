# The pinned plugins: source revision, id, panels, tools, settings and the bar
# widgets each brings (see plugins.nix for how a revision is chosen).
{ config, pkgs }:
let
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
