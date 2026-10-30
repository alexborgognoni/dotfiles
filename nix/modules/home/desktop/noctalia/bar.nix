# The bar: floating, transparent, every section in its own themed pill. The
# main display has the full bar, the others a workspaces-only one
# (my.desktop.mainMonitors; Hyprland's monitor events pick the right one, see
# hyprland/monitors.nix).
{
  config,
  lib,
  ...
}:
let
  theme = config.my.theme;
  deco = theme.decoration;
  square = deco.shellRadius == 0.0;

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
  config = lib.mkIf config.my.features.desktop.enable {
    programs.noctalia.settings = {
      # Floating, transparent bar: every section sits in its own themed bubble.
      bar.main = barCommon // {
        # One pill per single widget; "group:" entries share a pill.
        start = [
          "launcher"
        ]
        ++ lib.optional (has "hyprland-settings") "hypr-settings"
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
            # Left to right: what comes and goes first (the tray follows the
            # apps running, the printer shows with a job, AirPods when connected:
            # only the pill's left edge moves when their width changes), then
            # what is always there, the most used at the right end.
            members = [
              "tray"
            ]
            ++ lib.optional (has "printers") "printer"
            ++ lib.optional config.my.desktop.airpods.enable "airpods"
            ++ lib.optional (has "gamer-mode") "gamermode"
            ++ lib.optional (has "pomodoro") "pomodoro"
            ++ lib.optional (has "color_picker") "color-picker"
            ++ [ "clipboard" ];
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
      # monitor events show the right one per display (hyprland/monitors.nix).
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
    };
  };
}
