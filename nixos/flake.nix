{
  description = "Alex's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Applications and tools come from unstable (latest versions); the base
    # OS (kernel, systemd, desktop stack) stays on the stable release.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Firefox extensions (rycee's firefox-addons), also used by Stylix.
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nur.follows = "nur";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Only the Home Manager module is used; the package comes from nixpkgs.
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      lib = nixpkgs.lib;

      mkHost =
        {
          hostname,
          system ? "x86_64-linux",
          profile ? "personal",
        }:
        lib.nixosSystem {
          specialArgs = { inherit inputs self; };
          modules = [
            { nixpkgs.hostPlatform = system; }
            ./hosts/${hostname}
            ./modules/nixos
            { my.profile = profile; }
          ];
        };

      forAllSystems = lib.genAttrs [ "x86_64-linux" ];
    in
    {
      nixosConfigurations = {
        vm = mkHost {
          hostname = "vm";
          profile = "work";
        };
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      # Packages defined in this repository (pkgs/).
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ (import ./pkgs { inherit inputs; }) ];
          };
        in
        {
          inherit (pkgs) forgecode openwhispr;
        }
      );

      checks = forAllSystems (
        system:
        import ./checks {
          inherit self inputs;
          pkgs = nixpkgs.legacyPackages.${system};
        }
      );
    };
}
