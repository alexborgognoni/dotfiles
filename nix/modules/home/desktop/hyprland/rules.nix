# Window and layer rules: autostart placement, dialogs, the theme picker,
# Noctalia's layers.
{ config, lib, ... }:
let
  deco = config.my.theme.decoration;
in
{
  config = lib.mkIf config.my.features.desktop.enable {
    wayland.windowManager.hyprland.settings = {
      window_rule =
        lib.imap1 (i: a: {
          name = "autostart-${toString i}";
          match.initial_class = a.class;
          workspace = "${toString a.workspace} silent";
        }) (lib.filter (a: a.class != null && a.workspace != null) config.my.desktop.autostart)
        ++ [
          {
            name = "suppress-maximize-events";
            match.class = ".*";
            suppress_event = "maximize";
          }
          {
            name = "fix-xwayland-drags";
            match = {
              class = "^$";
              title = "^$";
              xwayland = true;
              float = true;
              fullscreen = false;
              pin = false;
            };
            no_focus = true;
          }
          {
            name = "noctalia-settings";
            match.class = "dev.noctalia.Noctalia";
            float = true;
            size = [
              1080
              920
            ];
          }
          {
            name = "theme-picker";
            match.class = "theme-picker";
            float = true;
            center = true;
            size = [
              1100
              560
            ];
          }
          {
            name = "floating-dialogs";
            match.class = "^(org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|xdg-desktop-portal-gtk)$";
            float = true;
          }
        ];

      layer_rule = {
        name = "noctalia";
        match.namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$";
        no_anim = true;
        ignore_alpha = 0.5;
        inherit (deco) blur;
        blur_popups = deco.blur;
      };
    };
  };
}
