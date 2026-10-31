# Voice dictation: Voxtype (whisper.cpp, local), started with the session and
# driven by a Hyprland key (Super+Shift+I, in hyprland/binds.nix) or the
# Noctalia "voxtype" bar widget. Press once to start, again to stop: the text
# is typed where the cursor is (wtype), or copied when typing is not possible.
#
# Toggle, not hold-to-talk: text typed while the key's modifiers are still held
# comes out as shortcuts. Hold-to-talk would be `voxtype record start` on press
# and `record stop` on release, with the output hooks and a Hyprland submap of
# Voxtype's troubleshooting guide.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.dictation;
  tomlFormat = pkgs.formats.toml { };

  voxtype = pkgs.unstable.voxtype.override { vulkanSupport = cfg.gpu != "cpu"; };

  language = if lib.length cfg.languages == 1 then lib.head cfg.languages else cfg.languages;

  # Voxtype records through ALSA. The ALSA of Nix reads the distribution's
  # /etc/alsa (on Ubuntu: a PulseAudio hook whose plugin it does not have) and
  # then finds no "default" device: this file sends it to PipeWire instead.
  alsaConfig = pkgs.writeText "voxtype-alsa.conf" ''
    pcm.!default { type pulse }
    ctl.!default { type pulse }
  '';

  # `vulkaninfo` must be on the PATH, or a GPU vendor cannot be turned into a
  # device number: both GPUs stay visible and the first (the Intel one) is used
  daemon = pkgs.writeShellScript "voxtype-daemon" ''
    export PATH=${lib.makeBinPath [ pkgs.vulkan-tools ]}:$PATH
    exec ${voxtype}/bin/voxtype daemon
  '';
in
{
  options.my.desktop.dictation = {
    enable = lib.mkEnableOption "voice dictation (Voxtype: daemon, key, bar widget)";

    languages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "en" ];
      example = [
        "en"
        "de"
      ];
      description = ''
        Languages you dictate in (ISO codes). One: always that language. Several:
        Whisper picks among them (more accurate than detecting among all ~99).
      '';
    };

    model = lib.mkOption {
      type = lib.types.package;
      # Whisper large-v3-turbo (multilingual, 1.6 GB): near large-v3 accuracy at
      # a fraction of the time. Pinned by hash; a smaller one is, for example,
      # ggml-small.bin from the same repository.
      default = pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin";
        hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
      };
      description = "The whisper.cpp (ggml) model file.";
    };

    gpu = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "auto"
        "intel"
        "nvidia"
        "amd"
      ];
      default = "cpu";
      description = ''
        Where Whisper runs. cpu: no GPU (a build without Vulkan). The others
        build with Vulkan: auto takes the first GPU, the vendors pick that GPU
        on a machine that has several.
      '';
    };

    onDemandLoading = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Load the model when a recording starts and free it afterwards (about a
        second slower to start; lets a discrete GPU sleep in between). Off: the
        model stays loaded, so a recording starts at once.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && config.my.features.desktop.enable) {
    home.packages = [ voxtype ];

    xdg.configFile."voxtype/config.toml".source = tomlFormat.generate "voxtype-config.toml" {
      # The key is Hyprland's (hyprland/binds.nix), not Voxtype's own (which
      # would need the input group)
      hotkey.enabled = false;
      state_file = "auto";

      # The floating waveform needs a frontend that nixpkgs does not build; the
      # bar widget shows the state
      osd.enabled = false;

      audio = {
        device = "default";
        pause_media = true;
      };

      whisper = {
        model = "${cfg.model}";
        inherit language;
        on_demand_loading = cfg.onDemandLoading;
      };

      output = {
        mode = "type";
        fallback_to_clipboard = true;
        notification.on_transcription = false;
      };
    };

    systemd.user.services.voxtype = lib.mkMerge [
      {
        Unit = {
          Description = "Voxtype voice dictation";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${daemon}";
          Restart = "on-failure";
          RestartSec = 3;
          Environment = [
            "ALSA_CONFIG_PATH=${alsaConfig}"
            "ALSA_PLUGIN_DIR=${pkgs.unstable.alsa-plugins}/lib/alsa-lib"
          ]
          ++ lib.optional (lib.elem cfg.gpu [
            "intel"
            "nvidia"
            "amd"
          ]) "VOXTYPE_VULKAN_DEVICE=${cfg.gpu}";
        };
        Install.WantedBy = [ "graphical-session.target" ];
        # A new model or settings need a new start (the daemon reads them once)
        Unit.X-Restart-Triggers = [
          "${config.xdg.configFile."voxtype/config.toml".source}"
          "${voxtype}"
        ];
      }
      # Standalone, GNOME starts graphical-session.target too (as for Noctalia)
      (lib.mkIf config.my.standalone {
        Unit.PartOf = lib.mkForce [ "hyprland-session.target" ];
        Unit.After = lib.mkForce [ "hyprland-session.target" ];
        Install.WantedBy = lib.mkForce [ "hyprland-session.target" ];
      })
    ];
  };
}
