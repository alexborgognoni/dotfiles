# AirPods in the Noctalia bar: the "AirPods" community plugin (battery, listening
# modes, ear detection) and the patched librepods daemon it drives. The plugin
# is pinned and offered to Noctalia as a read-only path source, so nothing is
# fetched or updated at runtime.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.airpods;

  daemon = pkgs.callPackage ../../../packages/librepods-daemon { };
  # The plugin looks for `librepods-ctl` on PATH
  ctl = pkgs.runCommand "librepods-ctl" { } ''
    mkdir -p $out/bin
    ln -s ${daemon}/bin/librepods-ctl $out/bin/librepods-ctl
  '';

  communityPlugins = pkgs.fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "community-plugins";
    rev = "cd454463cdafa8684e7e886fd9bd9bc99b51b462";
    hash = "sha256-ce+yhW5X3tiIUChNlDuD6S7q4ioWndbhQGnhWzxxebk=";
  };
  # A path source is a directory of plugin directories
  plugins = pkgs.runCommand "noctalia-plugins-airpods" { } ''
    mkdir -p $out
    cp -r ${communityPlugins}/airpods $out/airpods
  '';
in
{
  options.my.desktop.airpods.enable = lib.mkEnableOption "AirPods widget in the Noctalia bar (plugin and daemon)";

  config = lib.mkIf (cfg.enable && config.my.features.desktop.enable) {
    home.packages = [ ctl ];

    # The unit the daemon ships, with the Nix store path. Left out: the options
    # that work by dropping capabilities (ProtectClock, ProtectKernelModules,
    # ProtectKernelLogs, ProtectHostname, CapabilityBoundingSet): a user
    # manager is not allowed to (status 218/CAPABILITIES).
    systemd.user.services.librepods = {
      Unit = {
        Description = "librepods AirPods daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [ "QT_LOGGING_RULES=openpods.debug=false" ];
        ExecStart = "${daemon}/bin/librepods --headless";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        StateDirectory = "librepods";
        StateDirectoryMode = "0700";
        ConfigurationDirectory = "AirPodsTrayApp";
        ConfigurationDirectoryMode = "0700";
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = "%t";
        PrivateTmp = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = "AF_UNIX AF_BLUETOOTH AF_NETLINK";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    programs.noctalia.settings = {
      plugins = {
        enabled = [ "harveywuk/airpods" ];
        auto_update = "none";
        source = [
          {
            name = "pinned";
            kind = "path";
            location = "${plugins}";
            enabled = true;
          }
        ];
      };
      # Floating, like the shell panels (see noctalia.nix): an attached panel
      # inherits the transparent bar's background
      plugin_settings."harveywuk/airpods".panel_placement = "floating";
      # The widget is placed in the bar in noctalia.nix
      widget.airpods.type = "harveywuk/airpods:airpods";
    };
  };
}
