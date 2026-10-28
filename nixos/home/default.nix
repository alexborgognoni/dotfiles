{ osConfig, ... }:
let
  user = osConfig.my.user;
in
{
  imports = [ ../modules/home ];

  home = {
    username = user.name;
    homeDirectory = "/home/${user.name}";
    stateVersion = "26.05";
  };

  my.profile = osConfig.my.profile;
}
