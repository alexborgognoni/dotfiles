# Environment variables
export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.cargo/bin/:$PATH"
export NVIM_APPNAME="astronvim_v4"

fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

# Set name of the theme to load
ZSH_THEME="amuse"

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='vim'
else
    export EDITOR='nvim'
fi

# Aliases
alias c="clear"
alias cat="batcat --color=always"
alias k="kubectl"
alias ls="exa --icons"
alias nv="NVIM_APPNAME=astronvim_v4 nvim"
alias tf="terraform"

# plugins
source $ZSH/oh-my-zsh.sh
plugins=(git)

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# autojump
[[ -s /home/alex123/.autojump/etc/profile.d/autojump.sh ]] && source /home/alex123/.autojump/etc/profile.d/autojump.sh

autoload -U compinit && compinit -u

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# brew
# eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"


################################################
#          Work specific configurations        #
################################################

# ProxyMan
export FTP_PROXY="ftp://webproxy.deutsche-boerse.de:8080/"
export HTTPS_PROXY="http://webproxy.deutsche-boerse.de:8080/"
export HTTP_PROXY="http://webproxy.deutsche-boerse.de:8080/"
export NO_PROXY="tfe.deutsche-boerse.de"
export RSYNC_PROXY="rsync://webproxy.deutsche-boerse.de:8080/"
export ftp_proxy="ftp://webproxy.deutsche-boerse.de:8080/"
export http_proxy="http://webproxy.deutsche-boerse.de:8080/"
export https_proxy="http://webproxy.deutsche-boerse.de:8080/"
export no_proxy="tfe.deutsche-boerse.de"
export rsync_proxy="rsync://webproxy.deutsche-boerse.de:8080/"


# Map arrow keys
xmodmap -e "keycode 64 = Mode_switch" # set Alt_l as the "Mode_switch"
xmodmap -e "keycode 43 = h H Left H" # h
xmodmap -e "keycode 44 = j J Down J" # j
xmodmap -e "keycode 45 = k K Up K" # k
xmodmap -e "keycode 46 = l L Right L" # l
