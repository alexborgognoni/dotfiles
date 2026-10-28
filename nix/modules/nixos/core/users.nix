{ config, pkgs, ... }:
let
  user = config.my.user;
in
{
  programs.zsh.enable = true;
  # Completions for system packages
  environment.pathsToLink = [ "/share/zsh" ];

  users.users.${user.name} = {
    isNormalUser = true;
    description = user.fullName;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
    ];
  };
}
