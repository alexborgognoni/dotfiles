#############################################
#               Environment                 #
#############################################

export GOPATH="$HOME/go"
export NVM_DIR="$HOME/.nvm"
export REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"
export NODE_OPTIONS="--use-openssl-ca --use-system-ca"

# PATH configuration - organized for readability
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$GOPATH/bin"
export PATH="$PATH:$HOME/.config/composer/vendor/bin"
export PATH="$PATH:$HOME/.bun/bin"
export PATH="$PATH:$HOME/.opencode/bin"
export PATH="$PATH:$HOME/.config/herd-lite/bin"
export PATH="$PATH:$HOME/.local/bin"

export PHP_INI_SCAN_DIR="$HOME/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"

# Set EDITOR depending on SSH
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR="vim"
else
    export EDITOR="nvim"
fi

#############################################
#                History                    #
#############################################

HISTSIZE=5000
SAVEHIST=$HISTSIZE
HISTFILE="$HOME/.zsh_history"
HISTDUP=erase

setopt appendhistory sharehistory
setopt hist_ignore_space hist_ignore_dups hist_ignore_all_dups hist_save_no_dups hist_find_no_dups

#############################################
#             Key Bindings                  #
#############################################

bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# Word navigation with Ctrl+Arrow keys
bindkey '^[[1;5C' forward-word    # Ctrl+Right
bindkey '^[[1;5D' backward-word   # Ctrl+Left

#############################################
#                 Plugins                   #
#############################################

# Gcloud
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

# Pyenv initialization
export PYENV_ROOT="$HOME/.pyenv"
if [[ -d $PYENV_ROOT/bin ]]; then
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init - zsh)"
fi

# NVM - using zsh-nvm plugin for lazy loading
export NVM_LAZY_LOAD=true
export NVM_COMPLETION=true

# Homebrew - cached for faster shell startup
if [[ -f "$HOME/.brewenv_cache" ]]; then
    source "$HOME/.brewenv_cache"
else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    # Cache the brew environment for next time
    /home/linuxbrew/.linuxbrew/bin/brew shellenv > "$HOME/.brewenv_cache"
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Zinit
ZINIT_HOME="$HOME/.local/share/zinit"
ZINIT_BIN="$ZINIT_HOME/zinit.git"

if [[ ! -f $ZINIT_BIN/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing Zinit…%f"
    mkdir -p "$ZINIT_HOME" && chmod g-rwX "$ZINIT_HOME"
    git clone https://github.com/zdharma-continuum/zinit "$ZINIT_BIN" && \
        print -P "%F{34}Installation successful.%f%b" || \
        print -P "%F{160}Clone failed.%f%b"
fi

source "$ZINIT_BIN/zinit.zsh"

# Zinit plugins - using turbo mode for non-critical plugins
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# Load completions first
zinit light zsh-users/zsh-completions

# Initialize completion system with caching (runs once per day)
autoload -Uz compinit
if [[ -n ${HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# Load git plugin from OMZ via Zinit (provides git aliases)
zinit snippet OMZ::plugins/git/git.plugin.zsh

# Load zsh-nvm plugin for lazy NVM loading
zinit light lukechilds/zsh-nvm

# Load plugins with default configuration
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light Aloxaf/fzf-tab

zinit ice lucid wait'1'
zinit light joshskidmore/zsh-fzf-history-search

#############################################
#           Completion and FZF              #
#############################################

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no

# fzf-tab preview configuration
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always --icons $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'exa -1 --color=always --icons $realpath'

#############################################
#            External Configs               #
#############################################

# Load aliases
[ -f "$HOME/.zsh/aliases.zsh" ] && source "$HOME/.zsh/aliases.zsh"

# Load functions
[ -f "$HOME/.zsh/functions.zsh" ] && source "$HOME/.zsh/functions.zsh"

#############################################
#                Prompt                     #
#############################################

# Starship prompt (replaces Oh-My-Zsh)
eval "$(starship init zsh)"

# zoxide (loaded after prompt for faster startup)
eval "$(zoxide init zsh)"
