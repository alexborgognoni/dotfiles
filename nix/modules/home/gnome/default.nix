# GNOME on a standalone (Ubuntu) machine: only the basic preferences (clock,
# input sources, pointing devices, privacy). The session itself stays the
# distribution's vanilla GNOME, the backup session next to Hyprland: no Shell
# extensions, keybindings or custom theme. With my.desktop.themeToolkits
# Stylix themes GTK, the cursor and fonts (and GNOME with them).
{
  config,
  lib,
  ...
}:
let
  inherit (lib.hm.gvariant)
    mkTuple
    mkDouble
    mkEmptyArray
    type
    ;
  none = mkEmptyArray type.string;
in
{
  options.my.gnome.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.my.standalone && config.my.features.gui.enable;
    defaultText = lib.literalExpression "config.my.standalone && config.my.features.gui.enable";
    description = "Basic preferences of the distribution's GNOME desktop.";
  };

  config = lib.mkIf config.my.gnome.enable {
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        clock-format = "24h";
        clock-show-date = true;
        clock-show-seconds = false;
        clock-show-weekday = false;
        enable-animations = false;
        font-hinting = "slight";
        show-battery-percentage = true;
        text-scaling-factor = mkDouble 1.0;
      };
      "org/gnome/desktop/input-sources" = {
        per-window = false;
        sources = [
          (mkTuple [
            "xkb"
            "us"
          ])
          (mkTuple [
            "xkb"
            "gb"
          ])
        ];
        xkb-options = none;
      };
      "org/gnome/desktop/calendar".show-weekdate = true;
      "org/gnome/desktop/peripherals/mouse".speed = mkDouble (-0.17518248175182483);
      "org/gnome/desktop/peripherals/touchpad" = {
        click-method = "none";
        natural-scroll = true;
        send-events = "enabled";
        speed = mkDouble 0.29197080291970812;
        tap-to-click = false;
        two-finger-scrolling-enabled = true;
      };
      "org/gnome/desktop/privacy" = {
        remember-recent-files = true;
        recent-files-max-age = 30;
      };
    };
  };
}
