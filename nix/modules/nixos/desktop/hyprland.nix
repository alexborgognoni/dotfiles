{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    # Newest release (the stable channel lags a minor version behind)
    package = pkgs.unstable.hyprland;
    portalPackage = pkgs.unstable.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  security.polkit.enable = true;
  programs.dconf.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
