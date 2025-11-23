#!/bin/bash
set -euo pipefail

###############################################################################
# Package Dump Script
# Exports all currently installed packages to YAML files
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$DOTFILES_DIR/ansible/roles/packages/vars"

mkdir -p "$OUTPUT_DIR"

echo "Dumping packages from current system..."
echo "Output directory: $OUTPUT_DIR"
echo ""

###############################################################################
# APT Packages
###############################################################################

echo "📦 Dumping apt packages..."

# Get manually installed packages only (not dependencies)
apt-mark showmanual | sort > /tmp/apt-manual-all.txt

# Filter for common development tools and applications
cat > /tmp/apt-packages-filtered.txt << 'EOF'
7zip
ansible
autojump
automake
azure-cli
azure-functions-core-tools-4
bat
build-essential
cf8-cli
chafa
chrome-gnome-shell
cmake
code
curl
dconf-cli
docker-buildx-plugin
docker-ce
docker-ce-cli
docker-compose-plugin
eza
fd-find
ffmpeg
fzf
gh
git
gnome-shell-extensions
gnome-themes-extra
gnome-tweaks
gtk2-engines-murrine
imagemagick
inkscape
jq
libevent-dev
libncurses-dev
luarocks
lynx
make
moreutils
mysql-server
neofetch
pkg-config
poppler-utils
postgresql
python3
python3-pip
python3.10-venv
ripgrep
sassc
software-properties-common
terraform
tmux
tree
vim
wget
xclip
xcursorgen
yacc
zoxide
zsh
zsh-autosuggestions
zsh-syntax-highlighting
EOF

# Only keep packages that are actually installed
grep -Fxf /tmp/apt-packages-filtered.txt /tmp/apt-manual-all.txt > /tmp/apt-final.txt || true

echo "Found $(wc -l < /tmp/apt-final.txt) apt packages"

###############################################################################
# Snap Packages
###############################################################################

echo "📦 Dumping snap packages..."
snap list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v "^core" | grep -v "^gnome-" | grep -v "^gtk-" | grep -v "snapd" | sort > /tmp/snap-packages.txt || echo "" > /tmp/snap-packages.txt
echo "Found $(wc -l < /tmp/snap-packages.txt) snap packages"

###############################################################################
# Cargo Packages
###############################################################################

echo "📦 Dumping cargo packages..."
if command -v cargo &>/dev/null; then
    cargo install --list 2>/dev/null | grep "^[a-z]" | awk '{print $1}' | sort > /tmp/cargo-packages.txt
else
    echo "" > /tmp/cargo-packages.txt
fi
echo "Found $(wc -l < /tmp/cargo-packages.txt) cargo packages"

###############################################################################
# Pip Packages
###############################################################################

echo "📦 Dumping pip packages..."
pip list --format=freeze 2>/dev/null | grep -v "^-e" | cut -d'=' -f1 | sort > /tmp/pip-all-packages.txt || echo "" > /tmp/pip-all-packages.txt

# Filter for commonly used packages (not system dependencies)
grep -E "^(poetry|pre-commit|black|ruff|mypy|pytest|requests|fastapi|uvicorn|pydantic|click|rich|typer|httpx)" /tmp/pip-all-packages.txt > /tmp/pip-packages.txt || echo "" > /tmp/pip-packages.txt
echo "Found $(wc -l < /tmp/pip-packages.txt) pip packages"

###############################################################################
# NPM Global Packages
###############################################################################

echo "📦 Dumping npm global packages..."
if command -v npm &>/dev/null; then
    npm list -g --depth=0 2>/dev/null | grep -v "npm@" | awk '{print $2}' | grep "@" | cut -d'@' -f1 | sort > /tmp/npm-packages.txt || echo "" > /tmp/npm-packages.txt
else
    echo "" > /tmp/npm-packages.txt
fi
echo "Found $(wc -l < /tmp/npm-packages.txt) npm packages"

###############################################################################
# Homebrew Packages
###############################################################################

echo "📦 Dumping homebrew packages..."
if command -v brew &>/dev/null; then
    brew list --formula 2>/dev/null | sort > /tmp/brew-packages.txt || echo "" > /tmp/brew-packages.txt
else
    echo "" > /tmp/brew-packages.txt
fi
echo "Found $(wc -l < /tmp/brew-packages.txt) brew packages"

###############################################################################
# Generate YAML Files
###############################################################################

echo ""
echo "Generating YAML files..."

# Common packages (for all profiles)
cat > "$OUTPUT_DIR/common.yml" << 'YAML_END'
---
# Common packages for all profiles
# These packages are installed regardless of profile

apt_packages:
YAML_END

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    echo "  - name: $pkg" >> "$OUTPUT_DIR/common.yml"
done < /tmp/apt-final.txt

# Add other package managers
cat >> "$OUTPUT_DIR/common.yml" << 'YAML_END'

snap_packages:
YAML_END

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    echo "  - name: $pkg" >> "$OUTPUT_DIR/common.yml"
done < /tmp/snap-packages.txt

cat >> "$OUTPUT_DIR/common.yml" << 'YAML_END'

cargo_packages:
YAML_END

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    echo "  - name: $pkg" >> "$OUTPUT_DIR/common.yml"
done < /tmp/cargo-packages.txt

cat >> "$OUTPUT_DIR/common.yml" << 'YAML_END'

pip_packages:
YAML_END

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    echo "  - name: $pkg" >> "$OUTPUT_DIR/common.yml"
done < /tmp/pip-packages.txt

cat >> "$OUTPUT_DIR/common.yml" << 'YAML_END'

npm_packages:
YAML_END

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    echo "  - name: $pkg" >> "$OUTPUT_DIR/common.yml"
done < /tmp/npm-packages.txt

cat >> "$OUTPUT_DIR/common.yml" << 'YAML_END'

brew_packages:
YAML_END

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    echo "  - name: $pkg" >> "$OUTPUT_DIR/common.yml"
done < /tmp/brew-packages.txt

# Create empty personal and work files for user to customize
cat > "$OUTPUT_DIR/personal.yml" << 'YAML_END'
---
# Personal profile packages
# Add packages that should only be installed on personal machines

apt_packages: []
  # - name: spotify-client
  # - name: discord

snap_packages: []
  # - name: spotify

cargo_packages: []

pip_packages: []

npm_packages: []

brew_packages: []
YAML_END

cat > "$OUTPUT_DIR/work.yml" << 'YAML_END'
---
# Work profile packages
# Add packages that should only be installed on work machines

apt_packages: []
  # - name: microsoft-edge

snap_packages: []

cargo_packages: []

pip_packages: []

npm_packages: []

brew_packages: []
YAML_END

echo ""
echo "✅ Package dump complete!"
echo ""
echo "Files created:"
echo "  - $OUTPUT_DIR/common.yml ($(grep -c "name:" "$OUTPUT_DIR/common.yml") packages)"
echo "  - $OUTPUT_DIR/personal.yml (empty - add personal-only packages)"
echo "  - $OUTPUT_DIR/work.yml (empty - add work-only packages)"
echo ""
echo "Next steps:"
echo "  1. Review $OUTPUT_DIR/common.yml"
echo "  2. Move profile-specific packages to personal.yml or work.yml"
echo "  3. Add version pinning where needed (e.g., 'version: \"1.2.3\"')"
echo ""
