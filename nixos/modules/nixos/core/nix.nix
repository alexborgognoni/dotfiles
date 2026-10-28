{ config, inputs, ... }:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
    };

    # Pin the flake registry and NIX_PATH to the system nixpkgs, so
    # `nix shell nixpkgs#foo` and `nix-shell -p foo` use the same revision.
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    channel.enable = false;
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ (import ../../../pkgs { inherit inputs; }) ];

  # Compressed swap in RAM: headroom for large builds and evaluations.
  zramSwap.enable = true;

  programs.nh = {
    enable = true;
    flake = "/home/${config.my.user.name}/dotfiles/nixos";
    clean = {
      enable = true;
      extraArgs = "--keep 10 --keep-since 7d";
    };
  };
}
