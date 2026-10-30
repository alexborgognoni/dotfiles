# Ubuntu system layer with system-manager (NixOS-style /etc files, systemd
# units and tmpfiles on a non-NixOS distribution). Everything here is root
# level; the user level is Home Manager (modules/home, homes/<machine>.nix).
# apt packages, groups and the login shell stay with ansible/ubuntu.yml.
#
#   sudo system-manager switch --flake ~/dotfiles/nix#<machine>
#   (or: nix run ~/dotfiles/nix#system-manager -- switch --flake ... --sudo)
#
#   nix.nix        Nix's own settings
#   keyd.nix       key remapping
#   tweaks.nix     small /etc tweaks (Bluetooth, IPv4, inotify, uinput)
#   gpu.nix        GPU drivers for Nix-built apps
#   session.nix    the Hyprland session (GDM entry, portal, lock screen)
#   corporate.nix  corporate CA, Alt+hjkl (opt in per machine)
{ lib, ... }:
{
  imports = [
    ./corporate.nix
    ./gpu.nix
    ./keyd.nix
    ./nix.nix
    ./session.nix
    ./tweaks.nix
  ];

  options.my.user = lib.mkOption {
    type = lib.types.str;
    description = "The (single) user whose Home Manager configuration this system serves.";
  };

  config = {
    nixpkgs.hostPlatform = "x86_64-linux";

    # Users and groups belong to Ubuntu (and ansible/ubuntu.yml): never let
    # system-manager write /etc/passwd or /etc/group.
    services.userborn.enable = false;
  };
}
