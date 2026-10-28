# QEMU/KVM test VM running on the Ubuntu work laptop.
{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos-vm";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # The host sits behind Zscaler, which re-signs all TLS traffic.
  my.corporateCA = [ ./zscaler-root.crt ];

  my.secrets = {
    enable = true;
    file = ../../secrets/vm.yaml;
  };

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  # Host-only NIC (enp7s0) is for SSH from the host; it must never become the
  # default route, otherwise traffic bypasses the user-mode NIC with internet.
  networking.networkmanager.ensureProfiles.profiles.host-only = {
    connection = {
      id = "host-only";
      type = "ethernet";
      interface-name = "enp7s0";
    };
    ipv4 = {
      method = "auto";
      never-default = true;
    };
    ipv6.method = "disabled";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  users.users.alex.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICx+cqOXmeVOKmE6pOjeoiDOIY6DpS9QMulJDFgLJC7w alex.borgognoni@deutsche-boerse.com"
  ];

  # Test machine: allow unattended rebuilds over SSH.
  security.sudo.wheelNeedsPassword = false;

  # virtio-gpu without 3D acceleration: render Hyprland in software.
  environment.sessionVariables = {
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    GSK_RENDERER = "gl";
  };

  my.desktop.monitors = lib.mkDefault [
    {
      output = "Virtual-1";
      mode = "1920x1080@60";
      position = "0x0";
      scale = 1;
    }
  ];

  system.stateVersion = "26.05";
}
