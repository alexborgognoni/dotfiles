# User packages on NixOS: every group from packages/default.nix, installed at
# the NixOS level so they are evaluated once (not once per theme
# specialisation of the Home Manager configuration).
{ config, pkgs, ... }:
let
  groups = import ../../packages { inherit pkgs; };
in
{
  users.users.${config.my.user.name}.packages = groups.cli ++ groups.gui ++ groups.browsers;
}
