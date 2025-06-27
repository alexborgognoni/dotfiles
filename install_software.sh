#!/bin/bash
set -euo pipefail

# Create a temporary directory for downloads
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Using temp dir: $TEMP_DIR"

# ----------------------------------------
# Azure CLI
# ----------------------------------------
if ! command -v az &>/dev/null; then
  echo "Installing Azure CLI..."
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
  echo "Azure CLI already installed. Skipping."
fi

# ----------------------------------------
# Docker
# ----------------------------------------
if ! command -v docker &>/dev/null; then
  echo "Installing Docker..."
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo groupadd -f docker
  sudo usermod -aG docker "$USER"
  newgrp docker
else
  echo "Docker already installed. Skipping."
fi

# ----------------------------------------
# Google Chrome
# ----------------------------------------
if ! command -v google-chrome &>/dev/null; then
  echo "Installing Google Chrome..."
  wget -P "$TEMP_DIR" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt install -y "$TEMP_DIR/google-chrome-stable_current_amd64.deb"
else
  echo "Google Chrome already installed. Skipping."
fi

# ----------------------------------------
# Google Cloud CLI
# ----------------------------------------
# if ! command -v gcloud &>/dev/null; then
#   echo "Installing Google Cloud CLI..."
#   curl -sSL -o "$TEMP_DIR/gcloud.tar.gz" https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
#   tar -xf "$TEMP_DIR/gcloud.tar.gz" -C "$TEMP_DIR"
#   "$TEMP_DIR/google-cloud-sdk/install.sh" --screen-reader=true
# else
#   echo "Google Cloud CLI already installed. Skipping."
# fi

# ----------------------------------------
# Homebrew
# ----------------------------------------
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew already installed. Skipping."
fi

# ----------------------------------------
# Kitty Terminal
# ----------------------------------------
if ! command -v kitty &>/dev/null; then
  echo "Installing Kitty Terminal..."
  curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
  # Create symbolic links to add kitty and kitten to PATH (assuming ~/.local/bin is in your system-wide PATH)
  ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten ~/.local/bin/
  # Place the kitty.desktop file somewhere it can be found by the OS
  cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
  # If you want to open text files and images in kitty via your file manager also add the kitty-open.desktop file
  cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/
  # Update the paths to the kitty and its icon in the kitty desktop file(s)
  sed -i "s|Icon=kitty|Icon=$(readlink -f ~)/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
  sed -i "s|Exec=kitty|Exec=$(readlink -f ~)/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
  # Make xdg-terminal-exec (and hence desktop environments that support it use kitty)
  echo 'kitty.desktop' > ~/.config/xdg-terminals.list
else
  echo "Kitty already installed. Skipping."
fi

# ----------------------------------------
# Lazygit
# ----------------------------------------
if ! command -v lazygit &>/dev/null; then
  echo "Installing Lazygit..."
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
  curl -Lo "$TEMP_DIR/lazygit.tar.gz" "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf "$TEMP_DIR/lazygit.tar.gz" -C "$TEMP_DIR" lazygit
  sudo install "$TEMP_DIR/lazygit" -D -t /usr/local/bin/
else
  echo "Lazygit already installed. Skipping."
fi

# ----------------------------------------
# Neovim & AstronNvim
# ----------------------------------------
if ! command -v nvim &>/dev/null; then
  echo "Installing Neovim..."
  curl -Lo "$TEMP_DIR/nvim.tar.gz" https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
  sudo rm -rf /opt/nvim
  sudo tar -C /opt -xzf "$TEMP_DIR/nvim.tar.gz"
  # AstronNvim
  rm -rf ~/.config/nvim
  git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim
  rm -rf ~/.config/nvim/.git
else
  echo "Neovim already installed. Skipping."
fi

# ----------------------------------------
# NVM + Node.js
# ----------------------------------------
if ! command -v nvm &>/dev/null; then
  echo "Installing NVM and Node.js..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  # Create symbolic links to add kitty and kitten to PATH (assuming ~/.local/bin is in your system-wide PATH)
  ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten ~/.local/bin/
  # Place the kitty.desktop file somewhere it can be found by the OS
  cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
  # If you want to open text files and images in kitty via your file manager also add the kitty-open.desktop file
  cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/
  # Update the paths to the kitty and its icon in the kitty desktop file(s)
  sed -i "s|Icon=kitty|Icon=$(readlink -f ~)/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
  sed -i "s|Exec=kitty|Exec=$(readlink -f ~)/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
  # Make xdg-terminal-exec (and hence desktop environments that support it use kitty)
  echo 'kitty.desktop' > ~/.config/xdg-terminals.list
  source "$NVM_DIR/nvm.sh"
  nvm install node
else
  echo "NVM already installed. Skipping."
fi

# ----------------------------------------
# Rust + Cargo
# ----------------------------------------
if ! command -v rustup &>/dev/null; then
  echo "Installing Rust and Cargo..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  export PATH="$HOME/.cargo/bin:$PATH"
  rustup update
else
  echo "Rust already installed. Skipping."
fi

# ----------------------------------------
# Terraform
# ----------------------------------------
if ! command -v terraform &>/dev/null; then
  echo "Installing Terraform..."
  wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update
  sudo apt install -y terraform
else
  echo "Terraform already installed. Skipping."
fi

# ----------------------------------------
# Tmux
# ----------------------------------------
if ! command -v terraform &>/dev/null; then
  sudo add-apt-repository ppa:deadsnakes/ppa  # Example PPA — replace with real tmux PPA if available
  sudo apt update
  sudo apt install tmux -y

  # Tmux Plugin Manager
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

  # Tmux Catppuccin theme
  mkdir -p ~/.config/tmux/plugins/catppuccin
  git clone -b v2.1.3 https://github.com/catppuccin/tmux.git ~/.config/tmux/plugins/catppuccin/tmux
else
  echo "Tmux already installed. Skipping."
fi

# ----------------------------------------
# TypeScript
# ----------------------------------------
if ! command -v tsc &>/dev/null; then
  echo "Installing TypeScript..."
  npm install -g --save-dev typescript
else
  echo "TypeScript already installed. Skipping."
fi


# ----------------------------------------
# VS Code
# ----------------------------------------
if ! command -v code &>/dev/null; then
  echo "Installing Visual Studio Code..."
  wget -P "$TEMP_DIR" https://go.microsoft.com/fwlink/?LinkID=760868 -O "$TEMP_DIR/vscode.deb"
  sudo apt install -y "$TEMP_DIR/vscode.deb"
else
  echo "VS Code already installed. Skipping."
fi

# ----------------------------------------
# Yazi File Manager
# ----------------------------------------
if ! command -v yazi &>/dev/null; then
  echo "Installing Yazi..."
  TEMP_DIR="${TEMP_DIR:-/tmp}"
  mkdir -p "$TEMP_DIR"

  YAZI_URL=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest \
    | grep "browser_download_url" \
    | grep "x86_64-unknown-linux-gnu.tar.gz" \
    | cut -d '"' -f 4)

  curl -L "$YAZI_URL" -o "$TEMP_DIR/yazi.tar.gz"
  tar -xzf "$TEMP_DIR/yazi.tar.gz" -C "$TEMP_DIR"
  sudo install "$TEMP_DIR/yazi"*/yazi /usr/local/bin/
else
  echo "Yazi already installed. Skipping."
fi

# ----------------------------------------
# k9s
# ----------------------------------------
if ! command -v k9s &>/dev/null; then
  echo "Installing k9s..."
  curl -sS https://webinstall.dev/k9s | bash
else
  echo "k9s already installed. Skipping."
fi

# ----------------------------------------
# kubecolor
# ----------------------------------------
if ! command -v kubecolor &>/dev/null; then
  sudo apt-get update
  sudo apt-get install -y apt-transport-https wget
  VER=$(wget -qO- https://kubecolor.github.io/packages/deb/version)
  ARCH=$(dpkg --print-architecture)
  URL="https://kubecolor.github.io/packages/deb/pool/main/k/kubecolor/kubecolor_${VER}_${ARCH}.deb"
  wget -O "$TEMP_DIR/kubecolor.deb" "$URL"
  sudo dpkg -i "$TEMP_DIR/kubecolor.deb"
else
  echo "kubecolor already installed. Skipping."
fi

# ----------------------------------------
# oh-my-zsh
# ----------------------------------------
if [[ ! -f $(command -v omz) ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "oh-my-zsh already installed. Skipping."
fi

# ----------------------------------------
# Zoxide
# ----------------------------------------
if [[ ! -f $(command -v zoxide) ]]; then
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
else
  echo "Zoxide already installed. Skipping."
fi

# ----------------------------------------
# Zinit
# ----------------------------------------
if [[ ! -f $(command -v zinit) ]]; then
  curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh
else
  echo "Zinit already installed. Skipping."
fi


echo -e "\n✅ All done. Happy hacking!"
