# Nix itself: takes over /etc/nix/nix.conf (the installer's file is kept as a
# backup and restored on deactivation).
{ config, ... }:
{
  nix = {
    enable = true;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ config.my.user ];
      auto-optimise-store = true;
    };
  };
}
