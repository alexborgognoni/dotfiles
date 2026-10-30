# Key remapping with keyd, in every session and the console. The mapping is
# data (my.keyd.settings): this file has Caps Lock = Escape, other modules add
# theirs (corporate.nix: Alt+hjkl as arrow keys).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  keyd = import ../shared/keyd.nix;
in
{
  options.my.keyd.settings = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
    default = { };
    description = "keyd sections (keyd.conf), merged from all modules.";
  };

  config = {
    my.keyd.settings = keyd.settings;

    environment.etc."keyd/default.conf" = {
      # keyd's format: [ids] lists bare device ids, the rest is INI
      text =
        "[ids]\n" + lib.concatLines keyd.ids + "\n" + lib.generators.toINI { } config.my.keyd.settings;
      replaceExisting = true;
    };
    systemd.services.keyd = {
      description = "Key remapping daemon";
      wantedBy = [ "system-manager.target" ];
      restartTriggers = [ config.environment.etc."keyd/default.conf".source ];
      serviceConfig = {
        ExecStart = "${pkgs.keyd}/bin/keyd";
        Restart = "always";
      };
    };
  };
}
