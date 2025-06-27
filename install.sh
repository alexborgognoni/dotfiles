#!/bin/bash
set -euo pipefail

# ----------------------------------------
# Manually install software
# ----------------------------------------
echo "Installing some software 🍦 ..." 
chmod +x ./install_software.sh
./install_software.sh
echo "Done!"

# ----------------------------------------
# Install packages
# ----------------------------------------
echo "Installing apt packages 📦 ..." 
sudo apt update
while IFS= read -r line; do sudo apt install "$line" -y -qq; done <apt.pkglist
echo "Done!"

# ----------------------------------------
# Link config files
# ----------------------------------------
DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd)

# Define everything you want to link
TARGETS=(
  ".gitconfig"
  ".zshrc"
  ".fonts"
  "kitty"
  "nvim"
  "ranger"
  "tmux"
)

echo "🔗 Linking dotfiles from $DOTFILES_DIR..."

for item in "${TARGETS[@]}"; do
  src="$DOTFILES_DIR/$item"

  # If the filename starts with a dot, link to $HOME; otherwise link into ~/.config
  if [[ "$item" == .* ]]; then
    dest="$HOME/$item"
  else
    dest="$HOME/.config/$item"
    mkdir -p "$HOME/.config"
  fi

  if [[ "$item" == ".fonts" ]]; then
    fc-cache -fv
  fi

  if [ ! -e "$src" ]; then
    echo "⚠️  Skipping missing: $src"
    continue
  fi

  if [ -L "$dest" ] || [ -e "$dest" ]; then
    echo "🔁 $dest already exists. Skipping."
  else
    echo "✅ Linking $dest → $src"
    ln -s "$src" "$dest"
  fi
done

echo "🎉 All selected dotfiles linked successfully!"

echo "🔗 Linking Wallpapers..."
  ln -s $(pwd)/wallpapers ~/Pictures/Wallpapers
echo "🎉 Wallpapers linked successfully!"
