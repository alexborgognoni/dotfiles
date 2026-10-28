{
  hardware.graphics.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.fwupd.enable = true;
  services.fstrim.enable = true;
}
