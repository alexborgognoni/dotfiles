# Port of chezmoi/dot_zshrc.tmpl with plugins from nixpkgs instead of zinit.
# Dropped: nvm, pyenv, brew, bun and herd PATH hacks (the tools come from Nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  isWork = config.my.profile == "work";
  caBundle = "/etc/ssl/certs/ca-certificates.crt";
in
{
  # Your own scripts and tools installed with cargo / go install
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "${config.xdg.dataHome}/go/bin"
  ];

  programs.zsh = {
    enable = true;
    # Commands run by opencode get the environment it was started with, not
    # the Nix libraries its launcher adds (packages/default.nix: opencode)
    envExtra = lib.mkBefore ''
      if [[ -n ''${OPENCODE_CALLER_LD_LIBRARY_PATH+x} ]]; then
        if [[ -n $OPENCODE_CALLER_LD_LIBRARY_PATH ]]; then
          export LD_LIBRARY_PATH=$OPENCODE_CALLER_LD_LIBRARY_PATH
        else
          unset LD_LIBRARY_PATH
        fi
        unset OPENCODE_CALLER_LD_LIBRARY_PATH
      fi
    '';
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    defaultKeymap = "emacs";

    history = {
      size = 5000;
      save = 5000;
      path = "${config.xdg.stateHome}/zsh/history";
      append = true;
      share = true;
      ignoreSpace = true;
      ignoreDups = true;
      ignoreAllDups = true;
      saveNoDups = true;
      findNoDups = true;
      expireDuplicatesFirst = true;
    };

    # Order matters: fzf-tab must load before plugins that wrap widgets
    # (autosuggestions, syntax highlighting); Home Manager loads those last.
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
      {
        name = "omz-git";
        src = pkgs.oh-my-zsh;
        file = "share/oh-my-zsh/plugins/git/git.plugin.zsh";
      }
      {
        name = "zsh-fzf-history-search";
        src = pkgs.zsh-fzf-history-search;
        file = "share/zsh-fzf-history-search/zsh-fzf-history-search.plugin.zsh";
      }
    ];

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      c = "clear";
      k = "kubecolor";
      ls = "eza --icons=always";
      nv = "nvim";
      python = "python3";
      tf = "terraform";
      tree = "eza --tree --icons=always";
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      GOPATH = "${config.xdg.dataHome}/go";
    }
    // lib.optionalAttrs isWork {
      REQUESTS_CA_BUNDLE = caBundle;
      NODE_EXTRA_CA_CERTS = caBundle;
      # (Node 24 refuses --use-system-ca together with --use-openssl-ca)
      NODE_OPTIONS = "--use-openssl-ca";
    };

    initContent = lib.mkMerge [
      ''
        bindkey '^p' history-search-backward
        bindkey '^n' history-search-forward
        bindkey '^[[1;5C' forward-word
        bindkey '^[[1;5D' backward-word

        autoload -U edit-command-line
        zle -N edit-command-line
        bindkey '^x^e' edit-command-line

        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':completion:*' menu no

        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --icons=always --level 1 --color=always $realpath'
        zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --tree --icons=always --level 1 --color=always $realpath'
        zstyle ':fzf-tab:complete:*:options' fzf-preview
        zstyle ':fzf-tab:complete:*:argument-1' fzf-preview
        zstyle ':fzf-tab:complete:*:*' fzf-preview '
        if [[ -f $realpath ]]; then
          mime=$(file --mime-type -b $realpath)
          if [[ -n $KITTY_WINDOW_ID ]]; then
            if [[ $mime == image/* ]]; then
              kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no --place=''${FZF_PREVIEW_COLUMNS}x''${FZF_PREVIEW_LINES}@0x0 $realpath
            elif [[ $mime == application/pdf ]]; then
              pdftoppm -jpeg -f 1 -l 1 -singlefile -r 600 $realpath /tmp/fzf-pdf-preview 2>/dev/null && \
              kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no --place=''${FZF_PREVIEW_COLUMNS}x''${FZF_PREVIEW_LINES}@0x0 /tmp/fzf-pdf-preview.jpg
            else
              bat --color=always --style=numbers --line-range=:500 $realpath 2>/dev/null
            fi
          else
            bat --color=always --style=numbers --line-range=:500 $realpath 2>/dev/null
          fi
        elif [[ -d $realpath ]]; then
          eza --tree --icons=always --level 1 --color=always $realpath
        fi'

        mkcd() {
          mkdir -p "$1" && cd "$1"
        }

        # Local, untracked secrets and machine-specific settings
        [ -f "$HOME/.env.sh" ] && source "$HOME/.env.sh"
      ''

      # zsh-autosuggestions can leave its ghost text in the scrollback when
      # Enter is pressed; clear it and redraw before accepting the line.
      (lib.mkAfter ''
        _clear_autosuggest_then_accept() {
          if [[ -n $POSTDISPLAY ]]; then
            unset POSTDISPLAY
            zle -R
          fi
          zle accept-line
        }
        zle -N _clear_autosuggest_then_accept
        bindkey '^M' _clear_autosuggest_then_accept
        bindkey '^J' _clear_autosuggest_then_accept
      '')
    ];
  };

  home.packages = with pkgs; [
    zsh-completions # extra completion definitions (zinit: zsh-users/zsh-completions)
    file
    poppler-utils
  ];
}
