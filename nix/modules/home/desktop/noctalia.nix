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
      pkgs.unstable.noctalia.overrideAttrs (old: {
        # Upstream's tests run on Hydra for the same sources; icon_resolver
        # depends on the build host's environment.
        doCheck = false;
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/shell/lockscreen/lock_screen.cpp \
            --replace-fail 'const std::string pamService = "login";' 'const std::string pamService = "noctalia";'
        '';
      })
    else
      pkgs.unstable.noctalia;

  has = plugin: lib.elem plugin config.my.desktop.noctalia.plugins;
  roles = config.my.desktop.mainMonitors != [ ];

  # One look for every pill, single or grouped: same fill, border, padding,
  # corner shape and gap between the things inside
  pillPadding = 10;
  innerGap = 8;
  group =
    g:
    {
      fill = "surface_container";
      border = "outline_variant";
      opacity = theme.opacity.desktop;
      padding = pillPadding;
      widget_spacing = innerGap;
    }
    // lib.optionalAttrs square { radius = 0.0; }
    // g;

  # Compact system monitor value: icon and number, no gauge. The width is
  # fixed to the widest value, so the pill does not change size as digits
  # change (Inter's digits are proportional: "88%" is wider than "11%"):
  # percentages up to "99%", network speeds with the short suffix ("947B",
  # "574.1k", "12.3M"). Only a full "100%" outgrows the box.
  sysmon = stat: {
    type = "sysmon";
    inherit stat;
    visualization = "none";
    label_min_width = 36.0;
  };
  sysmonRate = stat: {
    type = "sysmon";
    inherit stat;
    visualization = "none";
    # Fast transfers are no fault: an accent tint, not the error red
    highlight_color = "secondary";
    network_speed_compact = true;
    label_min_width = 48.0;
  };

  # Geometry and pill style shared by the full bar and the workspaces-only bar
  barCommon = {
    position = "top";
    thickness = 42;
    background_opacity = 0.0;
    shadow = false;
    margin_edge = 6;
    margin_ends = 8;
    padding = 2;
    widget_spacing = innerGap;

    capsule = true;
    capsule_fill = "surface_container";
    capsule_opacity = theme.opacity.desktop;
    capsule_border = "outline_variant";
    capsule_thickness = 0.8;
    capsule_padding = pillPadding;
    # Text in one colour and icons in the accent, in every pill
    color = "on_surface";
    icon_color = "primary";
  }
  // lib.optionalAttrs square { capsule_radius = 0.0; };
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
            # Opened from a bar widget, a panel appears right below that widget
            # (the control center and the wallpaper picker, which have no key).
            # What a key also opens opens the same way from the bar: in the
            # centre of the screen, like the launcher and the clipboard.
            open_near_click_control_center = true;
            open_near_click_wallpaper = true;
            open_near_click_session = false;
            session_position = "center";
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
        bar.main = barCommon // {
          # One pill per single widget; "group:" entries share a pill.
          start = [
            "launcher"
          ]
          ++ lib.optional (has "keybind-cheatsheet") "keybinds"
          ++ [
            "workspaces"
            "active_window"
            "media"
          ];
          # A lane only gets the room the other two leave: a wide centre pushes
          # the first widgets of the right lane off the bar
          center = [ "group:when" ];
          end = [
            "group:tools"
            "group:stats"
            "group:system"
            "session"
          ];

          capsule_group = map group [
            {
              id = "when";
              members = [
                "notifications"
                "clock"
              ];
            }
            {
              id = "tools";
              # The tray's width changes with the apps running, so it sits at the
              # left end: only the pill's left edge moves, not its other widgets
              members =
                [ "tray" ]
                ++ lib.optional (has "pomodoro") "pomodoro"
                ++ [ "clipboard" ]
                ++ lib.optional (has "hyprland-settings") "hypr-settings"
                ++ lib.optional config.my.desktop.airpods.enable "airpods";
            }
            {
              id = "stats";
              members =
                lib.optionals (has "nvtop") [
                  "gpu"
                  "gpu-vram"
                ]
                ++ [
                  "cpu"
                  "ram"
                  "net-up"
                  "net-down"
                ];
            }
            {
              id = "system";
              members = [
                "network"
                "bluetooth"
                "volume"
                "battery"
              ];
            }
          ];
        };

        # Other displays than the main one (my.desktop.mainMonitors): only the
        # workspaces of that display. Both bars exist everywhere; Hyprland's
        # monitor events show the right one per display (hyprland.nix).
        bar.basic = lib.mkIf roles (
          barCommon
          // {
            start = [ "workspaces" ];
            center = [ ];
            end = [ ];
          }
        );
        # A (re)started Noctalia shows both bars everywhere: pick the right one
        # per display again
        hooks.started = lib.mkIf roles "monitor-roles --force";

        widget = {
          launcher = {
            capsule_fill = "primary";
            capsule_foreground = "on_primary";
            icon_color = "on_primary";
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
            format = "{:%H:%M   %a %d %b}";
            tooltip_format = "{:%A, %d %B %Y}";
          };
          cpu = sysmon "cpu_usage";
          ram = sysmon "ram_pct";
          net-up = sysmonRate "net_tx";
          net-down = sysmonRate "net_rx";
          # Only while something plays
          media = {
            max_length = 260.0;
            title_scroll = "on_hover";
            hide_when_no_media = true;
          };
          # Name of the connected device next to the icon
          bluetooth.show_label = true;
          session = {
            color = "error";
            icon_color = "error";
          };
        };

        # When a stat's value starts to tint toward the highlight colour
        # (activity) and where it is fully tinted (critical). Raised from the
        # defaults (50/90): ordinary work no longer lights up. Network speeds
        # are in MB/s.
        system.monitor = {
          cpu_usage_activity_threshold = 70;
          cpu_usage_critical_threshold = 95;
          gpu_usage_activity_threshold = 75;
          gpu_usage_critical_threshold = 98;
          gpu_vram_activity_threshold = 75;
          gpu_vram_critical_threshold = 95;
          ram_pct_activity_threshold = 80;
          ram_pct_critical_threshold = 95;
          net_rx_activity_threshold = 5;
          net_rx_critical_threshold = 50;
          net_tx_activity_threshold = 5;
          net_tx_critical_threshold = 50;
        };

        notification.background_opacity = theme.opacity.popups;
        osd.background_opacity = theme.opacity.popups;
      };
    };
  };
}
