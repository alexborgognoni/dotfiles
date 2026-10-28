# Standalone Home Manager on a non-NixOS distribution (Ubuntu work laptop):
# generic Linux integration, GPU drivers for Nix-built GUI apps, nh, and
# user-level secrets (decrypted with the admin age key).
{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.my;
  nvidia = cfg.gpu.nvidia;
  home = config.home.homeDirectory;
  isWork = cfg.profile == "work";
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  options.my.audio.server = lib.mkOption {
    type = lib.types.enum [
      "pipewire"
      "pulseaudio"
    ];
    default = "pipewire";
    description = ''
      Sound server on a standalone (Ubuntu) machine. Both are installed from
      apt (ansible/ubuntu.yml); this selects which one your user session runs.
      "pulseaudio" restores Ubuntu 22.04's default. Takes effect at the next
      login.
    '';
  };

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
    # XDG paths, app grid entries and session variables for a non-NixOS system
    targets.genericLinux.enable = true;

    # Drivers for Nix-built OpenGL/Vulkan apps: Mesa (Intel) always, NVIDIA
    # libraries pinned to the host driver. One-time root setup after the
    # first switch: `sudo $(which non-nixos-gpu-setup)`.
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

    # PipeWire instead of PulseAudio: enable the PipeWire user units from
    # Ubuntu's packages, mask PulseAudio and the old media session.
    xdg.configFile = lib.mkIf (cfg.audio.server == "pipewire") (
      let
        unit = name: config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/${name}";
        masked = config.lib.file.mkOutOfStoreSymlink "/dev/null";
      in
      {
        "systemd/user/sockets.target.wants/pipewire-pulse.socket".source = unit "pipewire-pulse.socket";
        "systemd/user/default.target.wants/pipewire-pulse.service".source = unit "pipewire-pulse.service";
        "systemd/user/pipewire.service.wants/wireplumber.service".source = unit "wireplumber.service";
        "systemd/user/pipewire-session-manager.service".source = unit "wireplumber.service";
        "systemd/user/pulseaudio.service".source = masked;
        "systemd/user/pulseaudio.socket".source = masked;
        "systemd/user/pipewire-media-session.service".source = masked;
      }
    );

    programs.home-manager.enable = true;

    programs.nh = {
      enable = true;
      homeFlake = "${home}/dotfiles/nix";
    };

    # User-level secrets, decrypted with the admin age key.
    sops = {
      age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
      secrets = {
        ssh-personal.sopsFile = ../../secrets/personal.yaml;
        gpg-personal.sopsFile = ../../secrets/personal.yaml;
      }
      // lib.optionalAttrs isWork {
        ssh-work.sopsFile = ../../secrets/work.yaml;
        gpg-work.sopsFile = ../../secrets/work.yaml;
      };
    };

    # sops-nix decrypts through a systemd user service. Without a running
    # user manager (containers, activation at early boot) run its install
    # script directly, so the secrets exist before they are used.
    home.activation.sopsWithoutSystemd = lib.hm.dag.entryBetween [ "importGpgKeys" ] [ "sops-nix" ] ''
      if ! ${config.systemd.user.systemctlPath} --user is-system-running >/dev/null 2>&1 \
        && [ "$(${config.systemd.user.systemctlPath} --user is-system-running 2>&1)" != degraded ]; then
        verboseEcho "Decrypting secrets without systemd"
        run ${lib.head (lib.toList config.systemd.user.services.sops-nix.Service.ExecStart)}
      fi
    '';

    my.identity.files = {
      sshPersonal = config.sops.secrets.ssh-personal.path;
      gpgPersonal = config.sops.secrets.gpg-personal.path;
    }
    // lib.optionalAttrs isWork {
      sshWork = config.sops.secrets.ssh-work.path;
      gpgWork = config.sops.secrets.gpg-work.path;
    };
  };
}
