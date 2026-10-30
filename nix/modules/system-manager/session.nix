# The Hyprland session next to GNOME: GDM entry, portal, lock screen PAM.
{
  config,
  lib,
  pkgs,
  homeConfig,
  ...
}:
let
  home = "/home/${config.my.user}";
  desktop = homeConfig.my.features.desktop.enable;
  portal = pkgs.unstable.xdg-desktop-portal-hyprland;
in
{
  config = {
    systemd.tmpfiles.rules = lib.optionals desktop [
      "L+ /usr/share/wayland-sessions/hyprland-nix.desktop - - - - /etc/dotfiles/hyprland-nix.desktop"
      # Ubuntu's portal frontend only reads backends from /usr/share
      "L+ /usr/share/xdg-desktop-portal/portals/hyprland.portal - - - - ${portal}/share/xdg-desktop-portal/portals/hyprland.portal"
      "L+ /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service - - - - ${portal}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service"
    ];

    # Hyprland is Wayland-only; GDM must offer Wayland sessions. GNOME keeps
    # running on whichever session is chosen (GDM remembers the last one, e.g.
    # "Ubuntu on Xorg"). Ubuntu's GDM has no drop-in directory, so this owns
    # the file (the original is kept and restored on deactivation).
    environment.etc."gdm3/custom.conf" = lib.mkIf desktop {
      text = ''
        # Managed by system-manager (~/dotfiles/nix/modules/system-manager)
        [daemon]
        WaylandEnable=true

        [security]

        [xdmcp]

        [chooser]

        [debug]
      '';
      replaceExisting = true;
    };

    # The portal's D-Bus activation starts this user unit
    environment.etc."systemd/user/xdg-desktop-portal-hyprland.service" = lib.mkIf desktop {
      source = "${portal}/share/systemd/user/xdg-desktop-portal-hyprland.service";
    };

    environment.etc."dotfiles/hyprland-nix.desktop" = lib.mkIf desktop {
      text = ''
        [Desktop Entry]
        Name=Hyprland (Nix)
        Comment=Hyprland and Noctalia from ~/dotfiles (Home Manager)
        Exec=${home}/.nix-profile/bin/hyprland-session
        Type=Application
        DesktopNames=Hyprland
      '';
    };

    # Noctalia's lock screen (patched to use this service, see
    # modules/home/desktop/noctalia.nix) runs Nix's PAM, which cannot parse
    # Ubuntu's /etc/pam.d files (Debian's @include): a stack of its own, with
    # absolute module paths as on NixOS.
    environment.etc."pam.d/noctalia" = lib.mkIf desktop {
      text = ''
        auth     required ${pkgs.linux-pam}/lib/security/pam_unix.so
        account  required ${pkgs.linux-pam}/lib/security/pam_unix.so
      '';
    };

    # Nix-built lock screens use Nix's PAM, whose pam_unix needs the setuid
    # helper at /run/wrappers/bin/unix_chkpwd (as on NixOS).
    security.wrappers.unix_chkpwd = lib.mkIf desktop {
      setuid = true;
      owner = "root";
      group = "root";
      source = "${pkgs.linux-pam}/bin/unix_chkpwd";
    };
  };
}
