#############################################
#               Environment                 #
#############################################

export ZSH="$HOME/.oh-my-zsh"
export GOPATH="$HOME/go"
export NVM_DIR="$HOME/.nvm"
export REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"
export NODE_OPTIONS="--use-openssl-ca --use-system-ca"

export PATH="$PATH:$HOME/.cargo/bin:/opt/nvim-linux-x86_64/bin:/usr/local/go/bin:$GOPATH/bin:$HOME/.config/composer/vendor/bin"
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

export PHP_INI_SCAN_DIR="$HOME/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"

# Set EDITOR depending on SSH
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR="vim"
else
    export EDITOR="nvim"
fi

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

#############################################
#                Zsh Theme                  #
#############################################

ZSH_THEME="amuse"

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

#############################################
#                 Plugins                   #
#############################################

# Gcloud
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi # updates PATH for the Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi # enables shell command completion for gcloud

# NVM
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Oh-My-Zsh
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

# zoxide
eval "$(zoxide init zsh)"

# zsh-completions
fpath+=${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/zsh-completions/src

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
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Zinit plugins
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

zinit ice lucid wait'0'
zinit light joshskidmore/zsh-fzf-history-search

#############################################
#           Completion and FZF              #
#############################################

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no

zstyle ':fzf-tab:complete:*' fzf-preview '
    if [ -d "$realpath" ]; then exa --tree --icons "$realpath"
    elif [ -f "$realpath" ]; then batcat --color=always "$realpath"
    else echo "$realpath"
    fi
'

zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview '
    if [ -d "$realpath" ]; then exa -a --tree --icons "$realpath"
    elif [ -f "$realpath" ]; then batcat --color=always "$realpath"
    else echo "$realpath"
    fi
'

#############################################
#                 Aliases                   #
#############################################

alias c="clear"
alias bat="batcat"
alias k="kubecolor"
alias ls="exa --icons"
alias nv="nvim"
alias python="python3"
alias rr="ranger"
alias tf="terraform"
alias tree="exa --tree --icons"

#############################################
#               Functions                   #
#############################################

mkcd() {
    mkdir -p "$1" && cd "$1"
}

y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd "$cwd"
    fi
    rm -f -- "$tmp"
}

ghcs() {
    local FUNCNAME="${funcstack[1]}"
    local TARGET="shell"
    local GH_DEBUG="${GH_DEBUG}"
    local GH_HOST="${GH_HOST}"
    local OPT OPTARG OPTIND

    while getopts "dht:-:" OPT; do
        if [[ "$OPT" = "-" ]]; then
            OPT="${OPTARG%%=*}"
            OPTARG="${OPTARG#*=}"
        fi
        case "$OPT" in
            d | debug) GH_DEBUG=api ;;
            h | help) echo "$__USAGE"; return 0 ;;
            hostname) GH_HOST="$OPTARG" ;;
            t | target) TARGET="$OPTARG" ;;
        esac
    done
    shift "$((OPTIND-1))"

    local TMPFILE
    TMPFILE="$(mktemp -t gh-copilotXXXXXX)"
    trap 'rm -f "$TMPFILE"' EXIT

    if GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot suggest -t "$TARGET" "$@" --shell-out "$TMPFILE"; then
        if [ -s "$TMPFILE" ]; then
            local FIXED_CMD
            FIXED_CMD="$(<"$TMPFILE")"
            print -s "$FIXED_CMD"
            eval "$FIXED_CMD"
        fi
    else
        return 1
    fi
}

ghce() {
    local FUNCNAME="${funcstack[1]}"
    local GH_DEBUG="${GH_DEBUG}"
    local GH_HOST="${GH_HOST}"
    local OPT OPTARG OPTIND

    while getopts "dh-:" OPT; do
        if [[ "$OPT" = "-" ]]; then
            OPT="${OPTARG%%=*}"
            OPTARG="${OPTARG#*=}"
        fi
        case "$OPT" in
            d | debug) GH_DEBUG=api ;;
            h | help) echo "$__USAGE"; return 0 ;;
            hostname) GH_HOST="$OPTARG" ;;
        esac
    done
    shift "$((OPTIND-1))"

    GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot explain "$@"
}
