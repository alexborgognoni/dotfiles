{ lib, ... }:
{
  imports = [
    ./theme.nix
    ./identity.nix
    ./shell
    ./terminal
    ./editor
    ./desktop
    ./browser.nix
    ./scripts.nix
  ];

  options.my.profile = lib.mkOption {
    type = lib.types.enum [
      "personal"
      "work"
    ];
    default = "personal";
  };

  config = {
    xdg.enable = true;
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
