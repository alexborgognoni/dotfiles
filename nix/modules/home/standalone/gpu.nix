# GPU drivers for Nix-built OpenGL/Vulkan apps on a distribution that ships its
# own driver.
{ config, lib, ... }:
let
  cfg = config.my;
  nvidia = cfg.gpu.nvidia;
in
{
  options.my.gpu.nvidia = {
    version = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "595.84";
      description = ''
        NVIDIA driver version of the host. Must match the driver the
        distribution installed exactly (cat /proc/driver/nvidia/version).
      '';
    };
    sha256 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Hash of NVIDIA-Linux-x86_64-<version>.run:
        nix store prefetch-file https://download.nvidia.com/XFree86/Linux-x86_64/<version>/NVIDIA-Linux-x86_64-<version>.run
      '';
    };
  };

  config = lib.mkIf cfg.standalone {
    # Drivers for Nix-built OpenGL/Vulkan apps: Mesa (Intel) always, NVIDIA
    # libraries pinned to the host driver. system-manager links them to
    # /run/opengl-driver (modules/system-manager).
    targets.genericLinux.gpu = {
      enable = true;
      nvidia = lib.mkIf (nvidia.version != null) {
        enable = true;
        inherit (nvidia) version sha256;
      };
    };

    # Warn when apt upgraded the NVIDIA driver and the pinned libraries no
    # longer match (Intel-rendered apps keep working).
    home.activation.nvidiaDriverCheck = lib.mkIf (nvidia.version != null) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -r /proc/driver/nvidia/version ]; then
          hostVersion="$(sed -n 's/.*Kernel Module for x86_64 *\([0-9.]*\).*/\1/p; s/.*Kernel Module *\([0-9.]*\) .*/\1/p' /proc/driver/nvidia/version | head -1)"
          if [ -n "$hostVersion" ] && [ "$hostVersion" != ${lib.escapeShellArg nvidia.version} ]; then
            warnEcho "NVIDIA driver is $hostVersion but my.gpu.nvidia.version is ${nvidia.version}: update version and sha256 in homes/$(hostname).nix"
          fi
        fi
      ''
    );
  };
}
