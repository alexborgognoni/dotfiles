# Sound on Ubuntu: PipeWire from Nix instead of Ubuntu's PulseAudio.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my;
in
{
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

  config = lib.mkIf cfg.standalone {
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
        "systemd/user/sockets.target.wants/pipewire-pulse.socket".source =
          "${pipewire}/pipewire-pulse.socket";
        # (no pipewire-session-manager alias: linked through the Nix store,
        # systemd would load it as a second, competing WirePlumber)
        "systemd/user/pipewire.service.wants/wireplumber.service".source =
          "${wireplumber}/wireplumber.service";
        "systemd/user/pulseaudio.service".source = masked;
        "systemd/user/pulseaudio.socket".source = masked;
        "systemd/user/pipewire-media-session.service".source = masked;
      }
    );
  };
}
