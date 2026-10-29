# Noctalia v5 (5.12 from nixpkgs; color roles use the 5.12 names
# surface_variant/outline): bar, launcher, control center (Wi-Fi, Bluetooth, audio,
# brightness, power), notifications, OSD, lock screen, clipboard history,
# screenshots, wallpaper and polkit agent.
#
# Colors come from the live theme pack (palettes/current.json points into
# ~/.local/state/theme/current), so theme previews recolor the shell instantly.
#
# Settings changed in Noctalia's GUI are stored in ~/.local/state/noctalia/
# settings.toml and override these defaults until reset.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  theme = config.my.theme;
  deco = theme.decoration;
  state = config.my.themeState;
  square = deco.shellRadius == 0.0;

  # The lock screen authenticates against the "login" PAM service. On other
  # distributions that file belongs to the distribution and Nix's PAM cannot
  # parse it (Debian's @include), so standalone Noctalia uses its own
  # "noctalia" service, provided by the system layer
  # (modules/system-manager: /etc/pam.d/noctalia).
  noctalia =
    if config.my.standalone then
      pkgs.noctalia.overrideAttrs (old: {
        # Upstream's tests run on Hydra for the same sources; icon_resolver
        # depends on the build host's environment.
        doCheck = false;
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/shell/lockscreen/lock_screen.cpp \
            --replace-fail 'const std::string pamService = "login";' 'const std::string pamService = "noctalia";'
        '';
      })
    else
      pkgs.noctalia;
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  options.my.wallpaper.rotation = {
    enable = lib.mkEnableOption "automatic wallpaper rotation within the current theme";
    interval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1800;
      description = "Seconds between wallpaper changes.";
    };
    order = lib.mkOption {
      type = lib.types.enum [
        "random"
        "alphabetical"
      ];
      default = "random";
    };
  };

  config = lib.mkIf config.my.features.desktop.enable {
    xdg.configFile."noctalia/palettes/current.json".source =
      config.lib.file.mkOutOfStoreSymlink "${state}/current/noctalia.json";

    # Noctalia hot-reloads config.toml; restarting it on every theme switch
    # (each theme has its own config) would make the bar flicker. Restart only
    # when the package changes.
    systemd.user.services.noctalia = lib.mkMerge [
      {
        Unit.X-Restart-Triggers = lib.mkForce [
          "${noctalia}"
        ];
      }
      # Standalone, GNOME starts graphical-session.target too: tie Noctalia
      # to the Hyprland session only.
      (lib.mkIf config.my.standalone {
        Unit.PartOf = lib.mkForce [ "hyprland-session.target" ];
        Unit.After = lib.mkForce [ "hyprland-session.target" ];
        Install.WantedBy = lib.mkForce [ "hyprland-session.target" ];
      })
    ];

    programs.noctalia = {
      enable = true;
      package = noctalia;
      systemd.enable = true;

      settings = {
        shell = {
          font_family = theme.fonts.sansSerif.name;
          corner_radius_scale = deco.shellRadius;
          polkit_agent = true;
          telemetry_enabled = false;
          # Everything the first-run wizard asks is configured here
          setup_wizard_enabled = false;
          settings_show_advanced = true;
          # Opened panels stay opaque; only the bar itself is see-through. An
          # attached panel inherits the bar's (zero) background opacity, so
          # they float below the bar instead, where transparency_mode applies.
          panel = {
            transparency_mode = "solid";
            control_center_placement = "floating";
            wallpaper_placement = "floating";
            session_placement = "floating";
          };
          screenshot.directory = "${config.xdg.userDirs.pictures}/Screenshots";
        };

        theme = {
          mode = theme.polarity;
          source = "custom";
          custom_palette = "current";
          # Stylix themes the applications; keep Noctalia's own app templates off.
          templates = {
            enable_builtin_templates = false;
            enable_community_templates = false;
          };
        };

        # The picker and rotation only offer the current theme's
        # wallpapers; `theme wallpaper rotate on|off|toggle` changes rotation live.
        wallpaper = {
          enabled = true;
          transition = [ "fade" ];
          transition_duration = 500;
          directory = "${state}/current/wallpapers";
          default.path = "${state}/current/wallpaper";
          automation = {
            enabled = config.my.wallpaper.rotation.enable;
            interval_seconds = config.my.wallpaper.rotation.interval;
            inherit (config.my.wallpaper.rotation) order;
            recursive = false;
          };
        };

        # Floating, transparent bar: every section sits in its own themed bubble.
        bar.main = {
          position = "top";
          thickness = 42;
          background_opacity = 0.0;
          shadow = false;
          margin_edge = 6;
          margin_ends = 8;
          padding = 2;
          widget_spacing = 8;

          capsule = true;
          capsule_fill = "surface_variant";
          capsule_opacity = theme.opacity.desktop;
          capsule_border = "outline";
          capsule_thickness = 0.8;
          capsule_padding = 10;
        }
        // lib.optionalAttrs square { capsule_radius = 0.0; }
        // {
          start = [
            "launcher"
            "workspaces"
            "media"
          ];
          center = [ "active_window" ];
          end = [
            "tray"
          ]
          ++ lib.optional config.my.desktop.airpods.enable "airpods"
          ++ [
            "group:status"
            "group:system"
            "clock"
            "session"
          ];

          capsule_group = [
            {
              id = "status";
              members = [
                "notifications"
                "clipboard"
              ];
              fill = "surface_variant";
              border = "outline";
              opacity = theme.opacity.desktop;
              widget_spacing = 10;
            }
            {
              id = "system";
              members = [
                "network"
                "bluetooth"
                "volume"
                "brightness"
                "battery"
              ];
              fill = "surface_variant";
              border = "outline";
              opacity = theme.opacity.desktop;
              widget_spacing = 12;
            }
          ];
        };

        widget = {
          launcher = {
            capsule_fill = "primary";
            capsule_foreground = "on_primary";
          };
          workspaces = {
            style = "regular";
            labels_only_when_occupied = false;
            hide_when_empty = false;
            focused_color = "primary";
            occupied_color = "secondary";
          };
          active_window = {
            max_length = 320;
            display = "icon_and_text";
            show_empty_label = false;
          };
          clock = {
            format = "{:%a %d %b   %H:%M}";
            tooltip_format = "{:%A, %d %B %Y}";
            color = "primary";
          };
          session = {
            color = "error";
          };
        };

        notification.background_opacity = theme.opacity.popups;
        osd.background_opacity = theme.opacity.popups;
      };
    };
  };
}
