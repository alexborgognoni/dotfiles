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

    # NixOS-style system configuration for non-NixOS machines (Ubuntu)
    system-manager = {
      url = "github:numtide/system-manager/release-26.05";
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

    # The AstroNvim distribution (a Lua plugin), pinned to a release; every
    # plugin it loads is built by Nix (modules/home/editor/astronvim).
    astronvim = {
      url = "github:AstroNvim/AstroNvim/v6.1.1";
      flake = false;
    };

    # Zen Browser (a Firefox fork, not in nixpkgs): the release binaries wrapped
    # for Nix, and a Home Manager module like programs.firefox.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
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
      inherit (nixpkgs) lib;

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
      tooling = system: import ./tooling.nix { pkgs = nixpkgs.legacyPackages.${system}; };

      overlay = import ./pkgs { inherit inputs; };

      # Standalone Home Manager for non-NixOS machines (e.g. Ubuntu)
      mkHome =
        {
          machine,
          system ? "x86_64-linux",
        }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              # NVIDIA libraries for targets.genericLinux.gpu
              nvidia.acceptLicense = true;
            };
            overlays = [ overlay ];
          };
        in
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
            themeCatalogue = import ./themes {
              inherit pkgs lib;
              base16 = inputs.stylix.inputs.base16.lib { inherit pkgs lib; };
            };
            packageGroups = import ./packages { inherit pkgs; };
          };
          modules = [
            ./modules/home
            ./homes/${machine}.nix
          ];
        };
    in
    {
      nixosConfigurations = {
        vm = mkHost {
          hostname = "vm";
          profile = "personal";
        };
      };

      homeConfigurations = {
        "alex@work-laptop" = mkHome { machine = "work-laptop"; };
      };

      # Root-level configuration of non-NixOS machines (system-manager); the
      # matching Home Manager configuration is passed in (GPU drivers, user).
      systemConfigs = {
        work-laptop = inputs.system-manager.lib.makeSystemConfig {
          modules = [
            ./modules/system-manager
            ./systems/work-laptop.nix
          ];
          overlays = [ overlay ];
          specialArgs = {
            homeConfig = self.homeConfigurations."alex@work-laptop".config;
          };
        };
      };

      # `nix fmt` formats the whole repository (nixfmt, shfmt, stylua);
      # `nix run path:nix#lint` also lints it (tooling.nix)
      formatter = forAllSystems (system: (tooling system).formatter);

      # Packages defined in this repository (pkgs/).
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ overlay ];
          };
        in
        {
          inherit (pkgs) forgecode openwhispr;
          # Pinned CLIs for bootstrapping non-NixOS machines
          home-manager = inputs.home-manager.packages.${system}.home-manager;
          system-manager = inputs.system-manager.packages.${system}.default;
          inherit (tooling system) lint;
        }
      );

      checks = forAllSystems (
        system:
        import ./checks {
          inherit self inputs;
          pkgs = nixpkgs.legacyPackages.${system};
        }
        // {
          lint-nix = (tooling system).lintNix self;
        }
      );
    };
}
