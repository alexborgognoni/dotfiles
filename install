#!/bin/bash
set -euo pipefail

###############################################################################
# Dotfiles Bootstrap Script
#
# This script sets up a fresh Ubuntu system with all dotfiles, packages,
# and GNOME configuration.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/alexborgognoni/dotfiles/main/install | bash
#   OR
#   ./install [--skip-secrets] [--profile personal|work]
#
# Options:
#   --skip-secrets    Skip SSH/GPG key setup
#   --profile         Set profile (personal or work)
###############################################################################

# Script options (can be set via environment or flags)
SKIP_SECRETS="${SKIP_SECRETS:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

step() {
    echo -e "\n${GREEN}==>${NC} ${BOLD}$1${NC}\n"
}

###############################################################################
# Clone Repository (if running from curl)
###############################################################################

# Check if we're running from a git repo or piped from curl
if [[ ! -d "$(dirname "${BASH_SOURCE[0]:-}")/.git" ]]; then
    info "Cloning dotfiles repository..."

    DOTFILES_DIR="$HOME/dotfiles"

    # Check if directory already exists
    if [[ -d "$DOTFILES_DIR" ]]; then
        warning "Directory $DOTFILES_DIR already exists"
        read -p "Remove and re-clone? [y/N]: " -n 1 -r
        echo ""
        if [[ ${REPLY:-} =~ ^[Yy]$ ]]; then
            rm -rf "$DOTFILES_DIR"
        else
            error "Installation aborted. Please remove $DOTFILES_DIR manually or run from that directory."
        fi
    fi

    # Install git if not present
    if ! command -v git &>/dev/null; then
        info "Installing git..."
        sudo apt update -qq
        sudo apt install -y -qq git
    fi

    # Clone repository
    git clone https://github.com/alexborgognoni/dotfiles.git "$DOTFILES_DIR"
    success "Repository cloned to $DOTFILES_DIR"

    # Execute the install script from the cloned repo, preserving env vars
    cd "$DOTFILES_DIR"
    exec env PROFILE="${PROFILE:-}" SKIP_SECRETS="${SKIP_SECRETS:-false}" bash install
    exit 0
fi

###############################################################################
# Pre-flight Checks
###############################################################################

# Check if running on Ubuntu
if [[ ! -f /etc/lsb-release ]]; then
    error "This script is designed for Ubuntu. Detected OS is not supported."
fi

# Get Ubuntu version
source /etc/lsb-release
info "Detected: ${DISTRIB_DESCRIPTION:-Unknown}"

# Check internet connection
if ! ping -c 1 google.com &>/dev/null; then
    error "No internet connection detected. Please connect to the internet and try again."
fi

###############################################################################
# Parse Command Line Arguments
###############################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-secrets)
            SKIP_SECRETS=true
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./install [--skip-secrets] [--profile personal|work]"
            echo ""
            echo "Options:"
            echo "  --skip-secrets    Skip SSH/GPG key setup"
            echo "  --profile         Set profile (personal or work)"
            echo ""
            echo "Environment variables:"
            echo "  PROFILE           Set profile (personal or work)"
            echo "  SKIP_SECRETS      Set to 'true' to skip secrets setup"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

###############################################################################
# Profile Selection
###############################################################################

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║               🚀 Borgo's Bootstrap Script 🚀              ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Prompt for profile
# Check if PROFILE is already set via environment variable or command line
if [[ -z "${PROFILE:-}" ]]; then
    # Check if running interactively
    if [[ -t 0 ]]; then
        # Interactive mode - prompt user
        while true; do
            read -p "Which profile? [personal/work]: " PROFILE
            case $PROFILE in
                personal|work)
                    break
                    ;;
                *)
                    warning "Invalid choice. Please enter 'personal' or 'work'."
                    ;;
            esac
        done
    else
        # Non-interactive mode (piped from curl) - default to personal
        PROFILE="personal"
        info "Running in non-interactive mode, defaulting to 'personal' profile"
        info "To use 'work' profile: export PROFILE=work && wget -qO- ... | bash"
    fi
fi

export PROFILE
success "Profile selected: $PROFILE"

# Get directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
info "Dotfiles directory: $DOTFILES_DIR"

###############################################################################
# Secrets Setup Prompt
###############################################################################

# Interactive secrets prompt (if not skipped via flag)
if [[ "$SKIP_SECRETS" != "true" ]] && [[ -t 0 ]]; then
    echo ""
    read -p "Set up SSH/GPG keys? [Y/n]: " -r REPLY </dev/tty
    REPLY=${REPLY:-Y}
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        SKIP_SECRETS=true
        info "Skipping SSH/GPG key setup"
    fi
fi

if [[ "$SKIP_SECRETS" == "true" ]]; then
    info "SSH/GPG key setup will be skipped"
else
    info "SSH/GPG key setup will be included"
fi

###############################################################################
# Step 1: Install Dependencies
###############################################################################

step "[1/6] Installing dependencies..."

info "Removing conflicting apt sources if present..."
# Remove old .list files
sudo rm -f /etc/apt/sources.list.d/github-cli.list \
    /etc/apt/sources.list.d/docker.list \
    /etc/apt/sources.list.d/azure-cli.list \
    /etc/apt/sources.list.d/hashicorp.list \
    /etc/apt/sources.list.d/cloudfoundry-cli.list \
    /etc/apt/sources.list.d/vscode.list \
    /etc/apt/sources.list.d/google-chrome.list \
    /etc/apt/sources.list.d/kubecolor.list \
    /etc/apt/sources.list.d/rabbitmq-erlang.list \
    /etc/apt/sources.list.d/rabbitmq-server.list \
    /etc/apt/sources.list.d/microsoft-prod.list \
    /etc/apt/sources.list.d/microsoft-edge.list \
    >/dev/null 2>&1 || true
# Remove old .sources files (DEB822 format)
sudo rm -f /etc/apt/sources.list.d/github-cli.sources \
    /etc/apt/sources.list.d/docker.sources \
    /etc/apt/sources.list.d/azure-cli.sources \
    /etc/apt/sources.list.d/hashicorp.sources \
    /etc/apt/sources.list.d/cloudfoundry-cli.sources \
    /etc/apt/sources.list.d/vscode.sources \
    /etc/apt/sources.list.d/google-chrome.sources \
    /etc/apt/sources.list.d/microsoft-prod.sources \
    /etc/apt/sources.list.d/microsoft-edge.sources \
    /etc/apt/sources.list.d/gierens.sources \
    >/dev/null 2>&1 || true

info "Updating package cache..."
sudo apt update -qq

info "Installing software-properties-common (for PPA support)..."
sudo apt install -y -qq software-properties-common

info "Removing old Ansible package if present..."
sudo apt remove -y -qq ansible >/dev/null 2>&1 || true

info "Adding Ansible PPA..."
sudo apt-add-repository -y ppa:ansible/ansible >/dev/null 2>&1
sudo apt update -qq

info "Installing Ansible and essential tools..."
sudo apt install -y -qq \
    ansible \
    git \
    curl \
    wget

success "Dependencies installed"

###############################################################################
# Step 2: Run Ansible Playbook
###############################################################################

step "[2/6] Running Ansible playbook..."

cd "$DOTFILES_DIR/ansible"

info "This will install packages and configure GNOME settings..."

# Refresh sudo credentials (already cached from apt commands above)
sudo -v

# Build ansible command (no --ask-become-pass needed, sudo is cached)
ANSIBLE_CMD="ansible-playbook -i inventory.yml playbook.yml -e profile=$PROFILE"

if [[ "$SKIP_SECRETS" == "true" ]]; then
    ANSIBLE_CMD="$ANSIBLE_CMD --skip-tags secrets"
fi

# Run ansible playbook with profile
if $ANSIBLE_CMD; then
    success "Ansible playbook completed successfully"
else
    error "Ansible playbook failed. Check the output above for errors."
fi

cd "$DOTFILES_DIR"

###############################################################################
# Step 3: Install chezmoi
###############################################################################

step "[3/6] Installing chezmoi..."

if command -v chezmoi &>/dev/null; then
    info "chezmoi is already installed"
else
    info "Installing chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

    # Add to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"

    success "chezmoi installed"
fi

###############################################################################
# Step 4: Initialize chezmoi
###############################################################################

step "[4/6] Initializing chezmoi..."

CHEZMOI_SOURCE="$DOTFILES_DIR/chezmoi"
CHEZMOI_DEFAULT="$HOME/.local/share/chezmoi"

# Create symlink from default chezmoi location to our source directory
mkdir -p "$HOME/.local/share"
if [[ -L "$CHEZMOI_DEFAULT" ]]; then
    info "chezmoi symlink already exists"
elif [[ -d "$CHEZMOI_DEFAULT" ]]; then
    warning "chezmoi directory exists but is not a symlink. Backing up and replacing."
    mv "$CHEZMOI_DEFAULT" "$CHEZMOI_DEFAULT.backup.$(date +%s)"
    ln -s "$CHEZMOI_SOURCE" "$CHEZMOI_DEFAULT"
    success "chezmoi symlink created (old directory backed up)"
else
    ln -s "$CHEZMOI_SOURCE" "$CHEZMOI_DEFAULT"
    success "chezmoi symlink created"
fi

# Initialize chezmoi
info "Initializing chezmoi..."
chezmoi init
success "chezmoi initialized"

###############################################################################
# Step 5: Apply Dotfiles
###############################################################################

step "[5/6] Applying dotfiles..."

chezmoi apply
success "Dotfiles applied"

###############################################################################
# Step 6: Post-Install Tasks
###############################################################################

step "[6/6] Running post-install tasks..."

# Set zsh as default shell if not already
if [[ "${SHELL:-}" != *"zsh"* ]]; then
    info "Setting zsh as default shell..."
    sudo chsh -s "$(which zsh)" "$USER"
    success "Default shell changed to zsh"
else
    info "zsh is already the default shell"
fi

# Font cache refresh
if [[ -d "$HOME/.fonts" ]]; then
    info "Refreshing font cache..."
    fc-cache -fv >/dev/null 2>&1
    success "Font cache refreshed"
fi

# Install TPM plugins (requires both TPM and tmux.conf from chezmoi)
if [[ -x "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" ]] && [[ -f "$HOME/.config/tmux/tmux.conf" ]]; then
    info "Installing tmux plugins..."
    if "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" &>/dev/null; then
        success "Tmux plugins installed"
    else
        warning "Tmux plugins will be installed on first tmux launch (prefix + I)"
    fi
fi

###############################################################################
# Completion
###############################################################################

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║                   🎉 Setup Complete! 🎉                   ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

info "Profile: $PROFILE"
info "Dotfiles: $DOTFILES_DIR"
echo ""

echo "Next steps:"
echo "  1. Log out and back in (or reboot) for all changes to take effect"
echo "  2. Open a new terminal to verify your configuration"
echo "  3. Run 'chezmoi edit <file>' to modify any dotfile"
echo "  4. Run 'chezmoi apply' to apply changes"
echo ""

warning "IMPORTANT: Please log out and back in for all changes to take effect!"
echo ""

success "Enjoy your new setup! 🚀"
