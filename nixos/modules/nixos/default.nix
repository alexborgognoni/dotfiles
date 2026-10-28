{ lib, ... }:
{
  imports = [
    ./core
    ./desktop
    ./theme.nix
    ./packages.nix
    ./home-manager.nix
  ];

  options.my = {
    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "alex";
      };
      fullName = lib.mkOption {
        type = lib.types.str;
        default = "Alex Borgognoni";
      };
    };

    profile = lib.mkOption {
      type = lib.types.enum [
        "personal"
        "work"
      ];
      default = "personal";
      description = "Selects identity-specific settings (git email, SSH hosts, CA handling).";
    };

    desktop.monitors = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = "auto";
        }
      ];
      description = "Hyprland monitor definitions (passed to hl.monitor).";
    };
  };
}
