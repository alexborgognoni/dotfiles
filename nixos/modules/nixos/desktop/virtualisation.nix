{ config, pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    package = pkgs.unstable.docker;
    autoPrune.enable = true;
  };

  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
  };
  programs.virt-manager.enable = true;

  users.users.${config.my.user.name}.extraGroups = [
    "docker"
    "libvirtd"
    "kvm"
  ];
}
