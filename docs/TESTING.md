# Testing Guide

Test your dotfiles setup before deploying to your main machine.

## Testing Strategy

**Two-phase approach:**

1. **Docker** (~5 min) - Quick validation of non-GUI components
2. **VM** (~30 min) - Full end-to-end testing with GNOME

## Phase 1: Docker Testing

### What's Tested

| ✅ Tested | ❌ Not Tested |
|-----------|---------------|
| Ansible syntax | GNOME desktop |
| APT packages | Snap packages |
| chezmoi templates | GUI applications |
| Profile system | Desktop themes |
| Manual installations | Extensions |

### Run Docker Tests

```bash
./scripts/test-docker.sh

# With specific profile
PROFILE=work ./scripts/test-docker.sh
```

**Duration**: ~5 minutes

## Phase 2: VM Testing

### VM Setup

```bash
# VirtualBox/VMware recommended
# - Ubuntu 22.04+ desktop ISO
# - 4GB+ RAM, 25GB+ disk
# - Take "fresh-install" snapshot
```

### Run Full Test

```bash
# 1. Clone dotfiles
git clone https://github.com/alexborgognoni/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Optional: Setup Bitwarden
bw login
export BW_SESSION=$(bw unlock --raw)

# 3. Run bootstrap
./install

# 4. Run automated tests
./scripts/test-profile-switching.sh
```

## Test Scripts

### test-profile-switching.sh

Validates the profile system with 11 tests:
- PROFILE environment variable
- Ansible inventory and group_vars
- Ansible playbook syntax
- Secrets skip functionality (`--skip-tags secrets`)
- chezmoi configuration template
- chezmoi template rendering
- Profile-specific template files
- Template helpers
- chezmoi dry run
- Profile-specific differences

```bash
./scripts/test-profile-switching.sh

# With secrets skipped
SKIP_SECRETS=true ./scripts/test-profile-switching.sh
```

**Duration**: ~2 minutes

### test-docker.sh

Validates non-GUI components in Docker container.

```bash
./scripts/test-docker.sh
```

**Duration**: ~5 minutes

## Manual Verification

### Shell & Terminal
- [ ] zsh is default shell
- [ ] Starship prompt works
- [ ] Custom aliases work
- [ ] Kitty terminal themed

### Development Tools
- [ ] Neovim opens with config
- [ ] Tmux works (Ctrl+a prefix)
- [ ] Git config correct
- [ ] Docker running

### GNOME Desktop
- [ ] Extensions enabled
- [ ] Theme applied
- [ ] Keyboard shortcuts work
- [ ] Wallpaper set

### Profile System
- [ ] Correct git email
- [ ] Profile-specific packages installed

## Test Scenarios

```bash
# Scenario 1: Fresh personal
PROFILE=personal ./install

# Scenario 2: Fresh work
PROFILE=work ./install

# Scenario 3: Skip secrets
SKIP_SECRETS=true PROFILE=personal ./install

# Scenario 4: Profile switch
PROFILE=work chezmoi apply
```

## Troubleshooting

### Docker Won't Build
```bash
docker system prune -a
docker build --no-cache -t dotfiles-test -f tests/Dockerfile .
```

### Ansible Fails
```bash
ansible-playbook ansible/playbook.yml --syntax-check
ansible-playbook ansible/playbook.yml -vvv
```

### chezmoi Fails
```bash
chezmoi diff
chezmoi apply -v
```

## Before Committing

1. `./scripts/test-docker.sh` - passes
2. `./scripts/test-profile-switching.sh` - passes
3. Test both profiles after major changes

---

**Duration Benchmarks:**
- Docker tests: ~5 minutes
- Profile tests: ~2 minutes
- Full VM bootstrap: 20-30 minutes
