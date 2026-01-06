# Packages Role

Multi-manager package installation for development tools and applications.

## Purpose

Installs packages from multiple package managers:
- **apt** - System packages, development tools
- **snap** - Sandboxed applications
- **cargo** - Rust packages
- **pip** - Python packages
- **npm** - Node.js packages
- **brew** - Homebrew packages
- **manual** - Custom installations (Kitty, Lazygit, Neovim, etc.)

## Variables

Package lists are defined in `vars/`:

| File | Description |
|------|-------------|
| `common.yml` | Packages for all profiles |
| `personal.yml` | Personal profile only |
| `work.yml` | Work profile only |
| `apt_repositories.yml` | APT repository definitions |
| `manual_tools.yml` | Manual installation definitions |

## Tags

- `packages` - All package tasks
- `apt` - APT packages only
- `snap` - Snap packages only
- `cargo` - Cargo packages only
- `pip` - Pip packages only
- `npm` - NPM packages only
- `brew` - Homebrew packages only
- `manual` - Manual installations only

## Handlers

- `fonts changed` - Refreshes font cache
- `docker group changed` - Updates user groups

## Dependencies

- `base` role
