# Dotfiles

Modern dotfiles for Ubuntu GNOME, managed with **chezmoi** and **Ansible**.

## Features

- **One-Command Install**: Fresh Ubuntu to fully configured system
- **Profile System**: Switch between personal and work configurations
- **Declarative Packages**: Automated package installation (apt, snap, cargo, pip, npm, brew)
- **GNOME Automation**: Desktop environment configured via dconf
- **Version Controlled**: All configs tracked and templated

## Quick Start

### Prerequisites

- Ubuntu 22.04+ with GNOME
- Internet connection
- sudo access

### Installation

**One-line install:**
```bash
curl -fsSL https://raw.githubusercontent.com/alexborgognoni/dotfiles/main/install | bash
```

**Or manually:**
```bash
# Clone repository
git clone https://github.com/alexborgognoni/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Optional: Login to Bitwarden for secret management
bw login
export BW_SESSION=$(bw unlock --raw)

# Run bootstrap
./install
```

Choose your profile when prompted:
- **personal**: Personal machine setup
- **work**: Work machine with corporate settings

### What Gets Configured

- **Shell**: zsh with plugins and custom prompt (starship)
- **Editor**: Neovim with full configuration
- **Terminal**: Kitty with custom config
- **Tools**: tmux, git, gh, bat, fzf, ripgrep, and more
- **Desktop**: GNOME extensions, themes, keybindings
- **Packages**: 80+ development tools and applications

### Testing

Run tests before deploying:

```bash
# Quick test (5 min) - Docker container
./scripts/test-docker.sh

# Full test (30 min) - Profile system validation
./scripts/test-profile-switching.sh

# Complete test - Fresh Ubuntu VM (recommended)
# See docs/TESTING.md for VM setup
```

### Updating Configs

After changing system settings, update the repository:

```bash
# Update GNOME settings
./scripts/dump-gnome-settings.sh

# Update package lists
./scripts/dump-packages.sh
```

## Documentation

- [**Profile System**](docs/PROFILES.md) - How work/personal profiles work
- [**Secret Management**](docs/SECRETS.md) - Using Bitwarden for secrets
- [**Testing Guide**](docs/TESTING.md) - Docker and VM testing
- [**Obsidian Setup**](docs/obsidian-setup.md) - Setting up Obsidian vault configs

## Project Structure

```
dotfiles/
├── install              # Bootstrap script
├── ansible/            # System automation
│   ├── playbook.yml   # Main playbook
│   └── roles/         # Packages, GNOME config
├── chezmoi/           # Dotfiles source
│   ├── dot_zshrc.tmpl
│   ├── dot_gitconfig.tmpl
│   └── dot_config/    # All .config files
├── scripts/           # Utility scripts
├── docs/             # Documentation
└── old/              # Deprecated files
```

## Architecture

- **chezmoi**: Manages dotfiles with Go templating for profile-specific configs
- **Ansible**: Automates system setup (packages, GNOME, repositories)
- **Profile System**: Single codebase for multiple machine types via templates

See [DESIGN.md](DESIGN.md) for detailed architecture decisions.

## Requirements

The bootstrap script will install:
- Ansible
- chezmoi
- git

All other dependencies are installed automatically.

## Future Improvements

- **Asset management**: Drop-in system for fonts, icons, wallpapers with manifests
- **Browser/editor configs**: Chrome and VS Code settings sync
- **Split keyboard**: Configuration management (when ready to redo)
- **Obsidian vault**: Auto-clone personal vault during bootstrap
- **Automated syncing**: Cronjob to keep package lists and GNOME settings updated
- **Theme system**: Unified theme management with one-command switching across all apps
- **Multi-OS support**: Arch Linux + Hyprland when Ubuntu+GNOME is stable

## License

MIT
