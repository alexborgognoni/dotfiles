# Standalone Home Manager on a non-NixOS distribution (Ubuntu work laptop):
# generic Linux integration, GPU drivers for Nix-built GUI apps, nh, and
# user-level secrets (decrypted with the admin age key).
{
  config,
  inputs,
  lib,
  pkgs,
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
      Sound server on a standalone (Ubuntu) machine: PipeWire from Nix, or
      "pulseaudio", Ubuntu 22.04's own default (left installed and untouched). Takes effect at the next
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

    # PipeWire instead of PulseAudio, from Nix: its user units, under the
    # same names as Ubuntu's (units in ~/.config take precedence), PulseAudio
    # and the old media session masked. Apps reach it through the PulseAudio
    # socket (pipewire-pulse) and Ubuntu's ALSA-to-PulseAudio plugin.
    home.packages = lib.mkIf (cfg.audio.server == "pipewire") [
      pkgs.pipewire # pw-cli, pw-top, ...
      pkgs.wireplumber # wpctl
    ];
    xdg.configFile = lib.mkIf (cfg.audio.server == "pipewire") (
      let
        pipewire = "${pkgs.pipewire}/lib/systemd/user";
        wireplumber = "${pkgs.wireplumber}/lib/systemd/user";
        masked = config.lib.file.mkOutOfStoreSymlink "/dev/null";
        # Nix's ALSA library would read Ubuntu's ALSA config (/etc/alsa/conf.d,
        # /etc/asound.conf), whose hooks load plugins only Ubuntu's library
        # has; that aborts the config and the sound card can't be opened.
        alsaConf = pkgs.runCommand "alsa-without-etc.conf" { } ''
          grep -vE '^\s*"(/var/lib/alsa/conf.d|/usr/etc/alsa/conf.d|/etc/alsa/conf.d|/etc/asound.conf\|\|\|/usr/etc/asound.conf)"\s*$' \
            ${pkgs.alsa-lib}/share/alsa/alsa.conf > $out
          ! grep -q '/etc/' $out || { echo "unexpected /etc reference left in alsa.conf" >&2; exit 1; }
        '';
        alsaDropin = {
          text = "[Service]\nEnvironment=ALSA_CONFIG_PATH=${alsaConf}\n";
        };
      in
      {
        "systemd/user/pipewire.service.d/alsa.conf" = alsaDropin;
        "systemd/user/pipewire-pulse.service.d/alsa.conf" = alsaDropin;
        "systemd/user/wireplumber.service.d/alsa.conf" = alsaDropin;
        "systemd/user/pipewire.service".source = "${pipewire}/pipewire.service";
        "systemd/user/pipewire.socket".source = "${pipewire}/pipewire.socket";
        "systemd/user/pipewire-pulse.service".source = "${pipewire}/pipewire-pulse.service";
        "systemd/user/pipewire-pulse.socket".source = "${pipewire}/pipewire-pulse.socket";
        "systemd/user/wireplumber.service".source = "${wireplumber}/wireplumber.service";
        "systemd/user/sockets.target.wants/pipewire.socket".source = "${pipewire}/pipewire.socket";
        "systemd/user/sockets.target.wants/pipewire-pulse.socket".source = "${pipewire}/pipewire-pulse.socket";
        # (no pipewire-session-manager alias: linked through the Nix store,
        # systemd would load it as a second, competing WirePlumber)
        "systemd/user/pipewire.service.wants/wireplumber.service".source = "${wireplumber}/wireplumber.service";
        "systemd/user/pulseaudio.service".source = masked;
        "systemd/user/pulseaudio.socket".source = masked;
        "systemd/user/pipewire-media-session.service".source = masked;
      }
    );

    # The Nix installer hooks only interactive shells (/etc/zsh/zshrc); load
    # Nix for every zsh (scripts, ssh commands, the display manager's login
    # shell). The script guards against being sourced twice.
    programs.zsh.envExtra = ''
      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi

      # The login shell is the distribution's zsh (so logging in works even
      # without Nix); interactive shells hand over to Nix's zsh, whose
      # plugins (fzf-tab's module) need Nix's newer glibc. Non-interactive
      # shells and scripts keep running in the shell they were started in.
      if [[ -o interactive && -z ''${HM_NIX_ZSH-} ]]; then
        hm_nix_zsh="$HOME/.nix-profile/bin/zsh"
        if [[ -x $hm_nix_zsh && $(readlink -f /proc/$$/exe) != $(readlink -f $hm_nix_zsh) ]]; then
          export HM_NIX_ZSH=1
          hm_zsh_opts=(-i)
          [[ -o login ]] && hm_zsh_opts+=(-l)
          if [[ -n ''${ZSH_EXECUTION_STRING-} ]]; then
            exec "$hm_nix_zsh" "''${hm_zsh_opts[@]}" -c "$ZSH_EXECUTION_STRING"
          fi
          exec "$hm_nix_zsh" "''${hm_zsh_opts[@]}"
        fi
        unset hm_nix_zsh
      fi
    '';

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
