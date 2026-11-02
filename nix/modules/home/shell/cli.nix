{ pkgs, ... }:
{
  programs = {
    starship = {
      enable = true;
      package = pkgs.unstable.starship;
      settings = {
        character = {
          success_symbol = "[\\$]()";
          error_symbol = "[\\$](bold red)";
        };
        aws.disabled = true;
        gcloud.disabled = true;
        directory = {
          truncation_length = 0;
          truncate_to_repo = false;
        };
      };
    };

    zoxide = {
      enable = true;
      package = pkgs.unstable.zoxide;
    };

    eza = {
      enable = true;
      package = pkgs.unstable.eza;
      icons = "always";
      git = true;
    };

    bat = {
      enable = true;
      package = pkgs.unstable.bat;
    };

    # zsh-fzf-history-search owns Ctrl-R; fzf itself is used by fzf-tab.
    fzf = {
      enable = true;
      package = pkgs.unstable.fzf;
      enableZshIntegration = false;
    };

    yazi = {
      enable = true;
      package = pkgs.unstable.yazi;
      shellWrapperName = "y";
      # E-books open in Readest (gui package group)
      settings = {
        opener.readest = [
          {
            run = ''readest "$@"'';
            desc = "Readest";
            orphan = true;
            for = "linux";
          }
        ];
        open.prepend_rules = [
          {
            mime = "application/epub+zip";
            use = "readest";
          }
        ];
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Tool versions of projects that pin them in mise.toml (the team's source
    # of truth, e.g. Daisy): `mise install` in the checkout. Downloaded
    # binaries need programs.nix-ld on NixOS (modules/nixos/core/nix-ld.nix).
    mise = {
      enable = true;
      package = pkgs.unstable.mise;
    };

    # Projects run on uv's standalone Pythons, never the Nix one: PyPI wheels
    # (numpy, pydantic, ...) need libstdc++, which a Nix-built interpreter
    # cannot find (a standalone Python uses the system loader, or nix-ld on
    # NixOS). The Nix python3 stays for scripts that use Nix's own packages.
    # In uv.toml, not a shell variable: IDEs and git hooks read it too. The uv
    # package itself is in the package groups.
    uv = {
      enable = true;
      package = null;
      settings.python-preference = "only-managed";
    };

    btop = {
      enable = true;
      package = pkgs.unstable.btop;
    };
    ripgrep = {
      enable = true;
      package = pkgs.unstable.ripgrep;
    };
    fd = {
      enable = true;
      package = pkgs.unstable.fd;
    };
    jq = {
      enable = true;
      package = pkgs.unstable.jq;
    };
    lazygit = {
      enable = true;
      package = pkgs.unstable.lazygit;
    };
    fastfetch = {
      enable = true;
      package = pkgs.unstable.fastfetch;
    };

    # Kubernetes tools: modules, so Stylix themes them (themes/apps.nix)
    k9s = {
      enable = true;
      package = pkgs.unstable.k9s;
    };
    kubecolor = {
      enable = true;
      package = pkgs.unstable.kubecolor;
    };
  };

  home.packages = with pkgs.unstable; [
    unzip
    wl-clipboard
  ];
}
