# Noctalia plugins, each pinned to the newest revision the packaged Noctalia
# (plugin API 30) can run, and offered to Noctalia as one read-only path
# source: nothing is fetched, installed or updated at runtime. A plugin
# is enabled per host with my.desktop.noctalia.plugins; its tools come with it.
#
# To pin another revision, take it from the `[[plugin.release]]` rows of
# catalog.toml in the source repository (the newest one whose plugin_api is
# at most the shell's), then `nix build` once with a wrong hash for the new one.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.noctalia.plugins;

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

  catalog = {
    airpods = {
      src = fetch {
        repo = "community-plugins";
        rev = "cd454463cdafa8684e7e886fd9bd9bc99b51b462";
        dir = "airpods";
        hash = "sha256-Adjbij+tJaPliawQtp0yXaQQiBSEVh5AmLC6Slbfikg=";
      };
      id = "harveywuk/airpods";
      panels = [ "panel" ];
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

    screen_recorder = {
      src = fetch {
        repo = "official-plugins";
        rev = "d696743c5e6718ed5bf6b4a4ef10d2636002d80c";
        dir = "screen_recorder";
        hash = "sha256-5NWh1QmqZgrKcwiOKuQ9vO5S2dV7excqutWnm3KAw/8=";
      };
      id = "noctalia/screen_recorder";
      packages = [ pkgs.unstable.gpu-screen-recorder ];
      settings = {
        # Remembers the monitor picked in the portal dialog the first time
        restore_portal = true;
        hide_inactive = true;
      };
      # Shown in the bar only while recording
      widget.recorder.type = "noctalia/screen_recorder:recorder";
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
      settings = {
        hyprland_lua_config = "${config.xdg.configHome}/hypr/hyprland.lua";
        show_undescribed = false;
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

    nvtop = {
      src = fetch {
        repo = "community-plugins";
        rev = "1543628d5c1a1c52be8392c71dbe286dd43e25aa";
        dir = "nvtop";
        hash = "sha256-tedc4uJOPSmNkmzv1WC+9KOsWCSmAEAJpduK+Krpbsw=";
      };
      id = "tordex/nvtop";
      panels = [ "panel" ];
      packages = [ pkgs.unstable.nvtopPackages.full ];
      patch = ''
        substituteInPlace nvtop/panel.luau \
          --replace-fail '"python3 "' '"${nvtopPython}/bin/python3 "'
      '';
    };
  };

  enabled = lib.genAttrs cfg (name: catalog.${name});

  # A path source is a directory of plugin directories
  plugins = pkgs.runCommand "noctalia-plugins" { } ''
    mkdir -p $out
    ${lib.concatStrings (
      lib.mapAttrsToList (name: p: ''
        cp -r ${p.src}/${name} $out/${name}
        chmod -R u+w $out/${name}
      '') enabled
    )}
    ${lib.concatStrings (
      lib.mapAttrsToList (
        name: p:
        lib.optionalString (p ? patch) ''
          (cd $out && ${p.patch})
        ''
      ) enabled
    )}
  '';
in
{
  options.my.desktop.noctalia.plugins = lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames catalog));
    default = [ ];
    description = "Pinned Noctalia plugins to enable, with the tools they call.";
  };

  config = lib.mkIf (cfg != [ ] && config.my.features.desktop.enable) {
    home.packages = lib.concatMap (p: p.packages or [ ]) (lib.attrValues enabled);

    programs.noctalia.settings = {
      plugins = {
        enabled = lib.mapAttrsToList (_: p: p.id) enabled;
        auto_update = "none";
        source = [
          {
            name = "pinned";
            kind = "path";
            location = "${plugins}";
            enabled = true;
          }
        ];
      };

      # Panels float, like the shell's own (see noctalia.nix): an attached
      # panel inherits the transparent bar's background. The keys are
      # <panel id>_placement / _position / _open_near_click.
      plugin_settings = lib.mapAttrs' (
        _: p:
        lib.nameValuePair p.id (
          lib.foldl' (acc: panel: acc // {
            "${panel}_placement" = "floating";
            "${panel}_position" = "auto";
            "${panel}_open_near_click" = true;
          }) { } (p.panels or [ ])
          // p.settings or { }
        )
      ) enabled;

      widget = lib.foldl' lib.recursiveUpdate { } (map (p: p.widget or { }) (lib.attrValues enabled));
    };
  };
}
