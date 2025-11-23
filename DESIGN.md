# Dotfiles System Design

## Philosophy

This dotfiles system embodies a **one-command install** philosophy: minimal manual intervention, maximum automation. The goal is to transform a fresh Ubuntu GNOME installation into a fully configured development environment with a single bootstrap command.

### Core Principles

1. **Declarative Configuration**: Define what you want, not how to get there
2. **Modular Architecture**: Each component (config files, packages, GNOME settings) is independently manageable
3. **Profile-Aware**: Seamlessly switch between work and personal configurations
4. **Idempotent Operations**: Safe to run repeatedly; only applies changes when needed
5. **Secret Management**: Sensitive data never committed to version control
6. **Version Control First**: All configuration changes tracked and reversible
7. **Future-Proof**: Designed to extend to multiple OS/DE combinations (Arch + Hyprland, etc.)

## Architecture

### Technology Stack

```
┌─────────────────────────────────────────────────────────┐
│                    Bootstrap Script                     │
│              (Single entry point: ./install)            │
└────────────────┬────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────▼────────┐  ┌─────▼──────────┐
│    Ansible     │  │    chezmoi     │
│   Automation   │  │  Config Mgmt   │
└───────┬────────┘  └─────┬──────────┘
        │                 │
        │                 │
┌───────▼─────────────────▼──────────────┐
│        System Configuration            │
│  ┌──────────┬──────────┬────────────┐  │
│  │ Packages │  GNOME   │  Dotfiles  │  │
│  │          │ Settings │            │  │
│  └──────────┴──────────┴────────────┘  │
└────────────────────────────────────────┘
```

### Why chezmoi?

**chezmoi** is our config file management solution because it provides:

- **Templating Engine**: Go templates for profile-specific configurations (work vs personal)
- **Secret Management**: Integration with 1Password, Bitwarden, age encryption
- **Conditional Logic**: OS-specific, hostname-specific, architecture-specific configs
- **Source State Tracking**: Maintains both source (in repo) and target (on system) states
- **Diff & Merge**: See changes before applying them
- **Script Execution**: Run scripts before/after applying configs

### Why Ansible?

**Ansible** handles system-level automation because it excels at:

- **Package Management**: Declarative apt, snap, flatpak, pip, cargo, brew installations
- **GNOME Configuration**: dconf/gsettings automation for desktop settings
- **Dependency Orchestration**: Install packages before configs that depend on them
- **Idempotent Tasks**: Safe to run multiple times
- **Extensibility**: Easy to add new roles for additional automation

### Division of Responsibilities

| Concern | Tool | Reason |
|---------|------|--------|
| Config Files | chezmoi | Templating, secrets, per-file versioning |
| Packages | Ansible | Dependency management, multiple package managers |
| GNOME Settings | Ansible | dconf automation, system-level changes |
| Fonts, Icons, Themes | Ansible | System installation + chezmoi for user-level |
| GNOME Extensions | Ansible | Installation + config via dconf |
| Bootstrap Logic | Bash | Simple, portable entry point |

## Directory Structure

```
dotfiles/
├── README.md                      # Project overview and quick start
├── DESIGN.md                      # This document
├── install                        # Bootstrap script (main entry point)
│
├── chezmoi/                       # chezmoi source directory
│   ├── .chezmoi.toml.tmpl        # chezmoi config (templated for profiles)
│   ├── .chezmoiignore            # Files to ignore
│   ├── .chezmoitemplates/        # Reusable template snippets
│   │
│   ├── dot_zshrc.tmpl            # ~/.zshrc (templated)
│   ├── dot_gitconfig.tmpl        # ~/.gitconfig (templated)
│   ├── dot_config/               # ~/.config/* mappings
│   │   ├── nvim/                 # Neovim config
│   │   ├── kitty/                # Kitty terminal config
│   │   ├── tmux/                 # Tmux config
│   │   └── starship.toml         # Starship prompt
│   │
│   ├── Pictures/                 # Wallpapers, etc.
│   │
│   ├── run_once_*                # Scripts run once on first apply
│   └── run_onchange_*            # Scripts run when file changes
│
├── ansible/                      # Ansible automation
│   ├── playbook.yml             # Main playbook
│   ├── inventory.yml            # Localhost inventory
│   ├── group_vars/              # Variable files
│   │   ├── all.yml              # Variables for all hosts
│   │   ├── personal.yml         # Personal profile variables
│   │   └── work.yml             # Work profile variables
│   │
│   └── roles/                   # Ansible roles
│       ├── base/                # Base system setup
│       ├── packages/            # Package installation
│       │   ├── tasks/
│       │   │   ├── main.yml
│       │   │   ├── apt.yml
│       │   │   ├── snap.yml
│       │   │   ├── flatpak.yml
│       │   │   ├── brew.yml
│       │   │   ├── cargo.yml
│       │   │   ├── pip.yml
│       │   │   └── manual.yml    # Manually installed software
│       │   └── vars/
│       │       ├── common.yml    # Packages for all profiles
│       │       ├── personal.yml  # Personal-only packages
│       │       └── work.yml      # Work-only packages
│       │
│       ├── gnome/               # GNOME desktop configuration
│       │   ├── tasks/
│       │   │   ├── main.yml
│       │   │   ├── settings.yml      # dconf settings
│       │   │   ├── extensions.yml    # GNOME extensions
│       │   │   ├── keybindings.yml   # Keyboard shortcuts
│       │   │   └── themes.yml        # GTK themes, icons, fonts
│       │   ├── files/
│       │   │   ├── dconf/           # dconf dumps
│       │   │   │   ├── common.conf
│       │   │   │   ├── personal.conf
│       │   │   │   └── work.conf
│       │   │   └── extensions/      # Extension configs
│       │   └── vars/
│       │       └── main.yml
│       │
│       ├── dotfiles/            # Chezmoi initialization
│       │   └── tasks/
│       │       └── main.yml     # Install chezmoi, init repo
│       │
│       └── secrets/             # Secret management setup
│           └── tasks/
│               └── main.yml     # GPG, SSH key setup
│
├── scripts/                     # Utility scripts
│   ├── bootstrap-ubuntu.sh      # Pre-Ansible Ubuntu prep
│   ├── dump-gnome-settings.sh   # Export current GNOME config
│   ├── dump-packages.sh         # Export installed packages
│   └── update-all.sh            # Update all package managers
│
└── docs/                        # Additional documentation
    ├── PROFILES.md              # Profile system guide
    ├── SECRETS.md               # Secret management guide
    └── TROUBLESHOOTING.md       # Common issues and solutions
```

## Configuration Profiles

### Profile System

The system supports multiple profiles through **chezmoi templates** and **Ansible variables**. Current profiles:

- **personal**: Home/personal machine setup
- **work**: Corporate environment with additional security/compliance requirements

### Profile Selection

During bootstrap, the user is prompted:

```bash
./install
# Which profile? [personal/work]: _
```

This sets the `PROFILE` variable used by both chezmoi and Ansible.

### Profile Differences

#### chezmoi Templates

Files use Go template conditions:

```go
# .zshrc.tmpl
export PATH="$HOME/.local/bin:$PATH"

{{- if eq .profile "work" }}
# Work-specific configurations
export CORPORATE_PROXY="http://proxy.company.com:8080"
export NO_PROXY="localhost,127.0.0.1,.company.internal"
{{- end }}

{{- if eq .profile "personal" }}
# Personal aliases and functions
alias personal-project="cd ~/projects/personal"
{{- end }}
```

#### Ansible Variables

Different package lists and settings per profile:

```yaml
# ansible/roles/packages/vars/personal.yml
personal_packages:
  - steam
  - discord
  - spotify-client

# ansible/roles/packages/vars/work.yml
work_packages:
  - microsoft-edge
  - teams
  - azure-cli
  - terraform
```

## Package Management

### Strategy

Each package manager has its own task file with version pinning support:

```yaml
# Example: ansible/roles/packages/tasks/apt.yml
- name: Install apt packages
  apt:
    name: "{{ item.name }}{{ item.version | default('') }}"
    state: "{{ item.state | default('present') }}"
  loop: "{{ apt_packages }}"

# Package definition with version pinning:
apt_packages:
  - name: neovim
    version: "=0.9.5-1"  # Specific version (optional)
  - name: zsh            # Latest version
  - name: docker-ce
    version: "=5:24.0.7-1~ubuntu.22.04~jammy"
```

### Package Lists

Organized by package manager and profile:

```yaml
# ansible/roles/packages/vars/common.yml (all profiles)
common_apt_packages:
  - git
  - zsh
  - tmux
  - neovim

common_cargo_packages:
  - bat
  - ripgrep
  - fd-find

common_apt_packages:
  - eza  # Modern ls replacement (from gierens repo)

# ansible/roles/packages/vars/personal.yml
personal_snap_packages:
  - spotify
  - discord

# ansible/roles/packages/vars/work.yml
work_snap_packages:
  - teams-for-linux
```

### Manual Installations

Software not in package managers (e.g., Kitty, Lazygit) handled via:

```yaml
# ansible/roles/packages/tasks/manual.yml
- name: Check if Kitty is installed
  command: which kitty
  register: kitty_check
  ignore_errors: yes
  changed_when: false

- name: Get installed Kitty version
  command: kitty --version
  register: kitty_version_output
  when: kitty_check.rc == 0
  changed_when: false

- name: Install Kitty
  shell: |
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
  when: kitty_check.rc != 0 or kitty_version_output.stdout is not search(kitty_desired_version)
```

### Dependency Management

Ansible task ordering ensures packages install before configs:

```yaml
# ansible/playbook.yml
- hosts: localhost
  roles:
    - base              # System prep (update, locale, timezone)
    - packages          # Install all packages first
    - gnome             # Configure GNOME (requires packages)
    - dotfiles          # Apply dotfiles (requires packages)
    - secrets           # Setup secrets last
```

## GNOME Configuration

### Settings Management

GNOME settings managed via **dconf dumps**:

```bash
# Export current settings
dconf dump / > ansible/roles/gnome/files/dconf/my-settings.conf

# Apply settings (Ansible task)
dconf load / < ansible/roles/gnome/files/dconf/common.conf
```

### File Organization

```
ansible/roles/gnome/files/dconf/
├── common.conf          # Settings for all profiles
├── personal.conf        # Personal-only settings
└── work.conf            # Work-only settings
```

Settings applied in order: common → profile-specific (overlays)

### Extensions

GNOME extensions installed and configured:

```yaml
# ansible/roles/gnome/tasks/extensions.yml
- name: Install GNOME extensions
  command: gnome-extensions install {{ item.uuid }}
  loop: "{{ gnome_extensions }}"

- name: Enable GNOME extensions
  command: gnome-extensions enable {{ item.uuid }}
  loop: "{{ gnome_extensions }}"

- name: Configure extension settings
  dconf:
    key: "{{ item.key }}"
    value: "{{ item.value }}"
  loop: "{{ extension_settings }}"
```

### Themes, Icons, Fonts

System-level installation via Ansible, user-level via chezmoi:

```yaml
# Ansible: System-wide theme installation
- name: Install GTK themes
  apt:
    name:
      - gnome-themes-extra
      - gtk2-engines-murrine

- name: Clone Catppuccin GTK theme
  git:
    repo: https://github.com/catppuccin/gtk
    dest: ~/.local/share/themes/catppuccin

# Ansible: Download and install cursor theme at runtime
- name: Download Volantes cursors
  get_url:
    url: https://github.com/varlesh/volantes-cursors/releases/download/v1.0.0/volantes-cursors.tar.gz
    dest: /tmp/volantes-cursors.tar.gz
```

## Secret Management

### Strategy

Never commit secrets to git. Use one of:

1. **Password Manager Integration** (recommended)
   - 1Password CLI (`op`)
   - Bitwarden CLI (`bw`)

2. **Age Encryption**
   - Encrypt entire files with age
   - Decrypt on apply

3. **Local Override Files**
   - `.env.sh` for machine-specific secrets
   - Ignored by git, sourced by shell configs

### Implementation

#### Password Manager (1Password example)

```toml
# chezmoi/.chezmoi.toml.tmpl
[onepassword]
    command = "op"

[data]
    profile = {{ .profile | quote }}
```

```bash
# chezmoi/dot_gitconfig.tmpl
[user]
    name = {{ .name | quote }}
    email = {{ onepasswordRead "op://Personal/Git/email" }}
    signingkey = {{ onepasswordRead "op://Personal/GPG/key" }}
```

#### Age Encryption

```bash
# Add encrypted file
chezmoi add --encrypted ~/.ssh/id_rsa

# Edit encrypted file
chezmoi edit ~/.ssh/id_rsa

# File stored encrypted in git, decrypted on apply
```

#### Local Overrides

```bash
# chezmoi/dot_zshrc.tmpl
# ... standard config ...

# Source machine-specific secrets (not in git)
[[ -f ~/.env.sh ]] && source ~/.env.sh
```

```bash
# ~/.env.sh (not tracked)
export OPENAI_API_KEY="sk-..."
export AWS_ACCESS_KEY_ID="..."
```

## Bootstrap Process

### User Experience

```bash
# 1. Clone the repo
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Run single command
./install

# Output:
# 🚀 Dotfiles Bootstrap
# Which profile? [personal/work]: personal
#
# [1/5] Installing dependencies...
# [2/5] Running Ansible playbook...
# [3/5] Initializing chezmoi...
# [4/5] Applying dotfiles...
# [5/5] Final setup...
#
# ✅ Setup complete! Please log out and back in for all changes to take effect.
```

### Implementation

```bash
#!/bin/bash
# install

set -euo pipefail

# Step 1: Prompt for profile
echo "🚀 Dotfiles Bootstrap"
read -p "Which profile? [personal/work]: " PROFILE
export PROFILE

# Step 2: Install minimal dependencies
echo "[1/5] Installing dependencies..."
sudo apt update
sudo apt install -y ansible git

# Step 3: Run Ansible playbook
echo "[2/5] Running Ansible playbook..."
cd ansible
ansible-playbook -i inventory.yml playbook.yml -e "profile=$PROFILE"

# Step 4: Initialize chezmoi (Ansible installed it)
echo "[3/5] Initializing chezmoi..."
chezmoi init --apply --source=~/dotfiles/chezmoi

# Step 5: Post-install
echo "[4/5] Running post-install tasks..."
# Set zsh as default shell
chsh -s $(which zsh)

# Step 6: Done
echo "[5/5] Final setup..."
echo "✅ Setup complete! Please log out and back in for all changes to take effect."
```

## Update Workflow

### Adding New Config

```bash
# 1. Add to chezmoi
chezmoi add ~/.config/newapp/config.toml

# 2. Edit if needed (converts to template)
chezmoi edit ~/.config/newapp/config.toml

# 3. Commit changes
cd ~/dotfiles/chezmoi
git add .
git commit -m "Add newapp configuration"
git push
```

### Exporting Current System State

Refresh package lists and GNOME settings:

```bash
# Update package lists
./scripts/dump-packages.sh

# Update GNOME settings
./scripts/dump-gnome-settings.sh

# Review and commit changes
git diff
git add ansible/roles/packages/vars/
git add ansible/roles/gnome/files/dconf/
git commit -m "Update package lists and GNOME settings"
```

### Installing on New Machine

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install
```

## Future Extensibility

### Multi-OS Support

When adding Arch + Hyprland support:

```
ansible/
├── playbook-ubuntu-gnome.yml
├── playbook-arch-hyprland.yml
└── roles/
    ├── packages-ubuntu/
    ├── packages-arch/
    ├── gnome/
    ├── hyprland/
    └── common/          # Shared configs (zsh, nvim, etc.)
```

Bootstrap script detects OS and runs appropriate playbook:

```bash
# install
if [[ -f /etc/arch-release ]]; then
    PLAYBOOK="playbook-arch-hyprland.yml"
elif [[ -f /etc/lsb-release ]]; then
    PLAYBOOK="playbook-ubuntu-gnome.yml"
fi
```

### Profile Expansion

Add new profiles by:

1. Creating `ansible/group_vars/newprofile.yml`
2. Creating `ansible/roles/gnome/files/dconf/newprofile.conf`
3. Creating `ansible/roles/packages/vars/newprofile.yml`
4. Adding conditions in chezmoi templates

## Design Decisions

### Why Not Just Ansible?

**Ansible alone is insufficient for dotfiles** because:
- No native file templating with conditionals
- Verbose for simple file management
- No built-in secret management
- Overkill for config file tracking

### Why Not Just chezmoi?

**chezmoi alone is insufficient** because:
- Can't install packages declaratively
- Can't manage system-level settings (dconf)
- Limited dependency orchestration
- Not designed for system automation

### Why Both?

Each tool does what it's best at:
- **chezmoi**: Config file management (its specialty)
- **Ansible**: System automation (its specialty)

### Alternatives Considered

| Alternative | Why Not? |
|-------------|----------|
| GNU Stow | No templating, no secret management, manual symlinks |
| Nix/Home Manager | Steep learning curve, unnecessary for Ubuntu focus |
| Plain Git + Scripts | Reinventing the wheel, no profile support |
| Ansible Only | See "Why Not Just Ansible?" above |

## Anti-Patterns to Avoid

1. **Committing Secrets**: Never commit API keys, tokens, or passwords
2. **Hardcoding Machine-Specific Paths**: Use templates and variables
3. **One Giant File**: Modular roles and files for maintainability
4. **No Version Pinning**: Specify versions for critical packages
5. **Applying Without Diff**: Always `chezmoi diff` before `chezmoi apply`
6. **Ignoring Idempotency**: Ensure all tasks safe to re-run
7. **Manual Steps**: Automate everything possible

## Maintenance

### Regular Tasks

1. **Update package lists** when installing new software
2. **Dump GNOME settings** after changing desktop config
3. **Test on fresh VM** before deploying to new machine
4. **Keep dependencies updated** (Ansible, chezmoi versions)
5. **Document manual steps** if automation is infeasible

### Versioning

Follow semantic versioning for playbook changes:
- **Major**: Breaking changes (structure changes)
- **Minor**: New features (new packages, configs)
- **Patch**: Bug fixes, documentation updates

## References

- [chezmoi Documentation](https://www.chezmoi.io/)
- [Ansible Documentation](https://docs.ansible.com/)
- [GNOME dconf Manual](https://wiki.gnome.org/Projects/dconf)
- [Simple Dotfiles by shaky.sh](https://shaky.sh/simple-dotfiles/)

---

**Last Updated**: 2025-11-21
**Target OS**: Ubuntu 22.04+ with GNOME
**Status**: Design Phase
