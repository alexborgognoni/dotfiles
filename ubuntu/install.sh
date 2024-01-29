#!/bin/bash

# Install packages
while IFS= read -r line; do sudo apt install "$line" -y -qq; done <apt.pkglist
while IFS= read -r line; do sudo snap install "$line"; done <snap.pkglist
while IFS= read -r line; do brew install "$line"; done <brew.pkglist

# Link config files
sudo ln -s $(pwd)/../.zshrc ~/.zshrc
sudo mkdir -p ~/.config/tmux && sudo ln -s $(pwd)/../tmux/tmux.conf ~/.config/tmux/tmux.conf

# Install neovim
sudo mv ~/.config/nvim ~/.config/nvim.bak
sudo mv ~/.local/share/nvim ~/.local/share/nvim.bak
sudo mv ~/.local/state/nvim ~/.local/state/nvim.bak
sudo mv ~/.cache/nvim ~/.cache/nvim.bak
git clone --depth 1 https://github.com/AstroNvim/AstroNvim ~/.config/nvim
sudo mkdir -p ~/.config/nvim/lua/user && sudo ln -s $(pwd)/../nvim/lua/user/init.lua ~/.config/nvim/lua/user/init.lua

# Install Regolith cattpuccin theme
sudo ln -s ./regolith-look/catppuccin /usr/share/regolith-look/catppuccin
