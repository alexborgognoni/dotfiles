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
      icons = "auto";
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
  };

  home.packages = with pkgs.unstable; [
    unzip
    wl-clipboard
  ];
}
