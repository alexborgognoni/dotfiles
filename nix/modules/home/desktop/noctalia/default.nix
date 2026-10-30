# Noctalia v5 (nixos-unstable): bar, launcher, control center (Wi-Fi,
# Bluetooth, audio, brightness, power), notifications, OSD, lock screen,
# clipboard history, screenshots, wallpaper and polkit agent.
#
#   default.nix        this file: the service, shell, theme, wallpaper
#   package.nix        the package (lock screen PAM service when standalone)
#   bar.nix            bar layout, pills, widgets, system monitor
#   plugins.nix        the pinned plugins (plugin-catalog.nix: the data)
#   airpods.nix        the AirPods plugin's daemon
#
# Colors come from the live theme pack (palettes/current.json points into
# ~/.local/state/theme/current), so theme previews recolor the shell instantly.
# Color roles use Noctalia 5.4's names (surface_container, outline_variant).
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

  noctalia = import ./package.nix { inherit config pkgs; };
in
{
  imports = [
    inputs.noctalia.homeModules.default
    ./airpods.nix
    ./bar.nix
    ./plugins.nix
  ];

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

        notification.background_opacity = theme.opacity.popups;
        osd.background_opacity = theme.opacity.popups;
      };
    };
  };
}
