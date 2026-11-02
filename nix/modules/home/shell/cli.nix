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

    # uv uses the Nix interpreters (python3.12 .. 3.14, wheel-capable: see
    # pkgs/python-native-libs) and never downloads a standalone Python: that is
    # an unpatched binary, which needs nix-ld on NixOS. In uv.toml, not a shell
    # variable: IDEs and git hooks read it too. The uv package itself is in the
    # package groups.
    uv = {
      enable = true;
      package = null;
      settings = {
        python-preference = "only-system";
        python-downloads = "never";
      };
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

  # uv's default Python where a project does not pin one (its own
  # .python-version or requires-python wins): 3.13, not the newest. The wheel
  # ecosystem lags the newest Python (a tool such as postgres-mcp has no wheels
  # for it), and with only the Nix interpreters on PATH uv would take 3.14, the
  # one `python3` is for scripts.
  xdg.configFile."uv/.python-version".text = "3.13\n";
}
