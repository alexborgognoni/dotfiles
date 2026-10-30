# GPU drivers for Nix-built apps: the same driver set Home Manager's
# targets.genericLinux.gpu defines (Mesa + the pinned NVIDIA libraries), at the
# path NixOS uses.
{ homeConfig, ... }:
{
  systemd.tmpfiles.rules = [
    "L+ /run/opengl-driver - - - - ${homeConfig.targets.genericLinux.gpu.drivers}"
  ];
}
