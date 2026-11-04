# Integration of the Noctalia "Hyprland Settings" panel (display tweaks,
# input, look): it writes ~/.config/hypr/hyprland-settings.lua (state, not
# config), which Hyprland loads last. Not for displays: Hyprland ranks output
# managers (kanshi, wlr-randr, wdisplays) above hyprctl calls above the
# config file, so once kanshi has applied a profile the panel's display
# changes are saved but ignored. Displays: Nix (kanshi, scales), one-offs with
# wdisplays/wlr-randr.
{ config, lib, ... }:
lib.mkIf
  (
    config.my.features.desktop.enable && lib.elem "hyprland-settings" config.my.desktop.noctalia.plugins
  )
  {
    # The file must exist before the config requires it, or Hyprland never
    # watches it. Created at switch time, rewritten by the panel.
    home.activation.hyprlandSettingsFile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ ! -e "${config.xdg.configHome}/hypr/hyprland-settings.lua" ]; then
        run touch "${config.xdg.configHome}/hypr/hyprland-settings.lua"
      fi
    '';

    # Written this way because the panel looks for exactly this line to see
    # that it is connected.
    wayland.windowManager.hyprland.extraConfig = lib.mkOrder 900 ''
      pcall(function() require("hyprland-settings") end)
    '';
  }
