# Home Manager as a NixOS module. The Home Manager modules don't read
# osConfig; this file forwards the NixOS values they need.
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  user = config.my.user;
in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs;
      themeCatalogue = config.my.themes;
      packageGroups = import ../../packages { inherit pkgs; };
    };

    users.${user.name} = {
      imports = [ ../../modules/home ];

      home = {
        username = user.name;
        homeDirectory = "/home/${user.name}";
        stateVersion = "26.05";
      };

      my = {
        inherit (config.my) profile;
        keyboard.layout = config.services.xserver.xkb.layout;
        desktop.monitors = config.my.desktop.monitors;
      };
    };
  };
}
