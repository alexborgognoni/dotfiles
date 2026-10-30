# Corporate network rescue (Zscaler, Ubuntu's NetworkManager and systemd): run
# as they are, with the system's tools.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.corporate.enable {
    home.packages = map (name: pkgs.writeScriptBin name (builtins.readFile (./scripts + "/${name}"))) [
      "fix-zscaler"
      "net-diag"
      "net-rescue"
    ];
  };
}
