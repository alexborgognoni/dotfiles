# Testing Guide

This guide explains how to test the dotfiles setup before deploying to your main machine.

## Testing Strategy

Use a **two-phase approach**:

1. **Docker** - Quick testing of non-GUI components (~5 minutes)
2. **VM** - Full end-to-end testing including GNOME (~30 minutes)

## Phase 1: Docker Testing

### What Docker Tests

✅ **Tested in Docker:**
- Ansible playbook syntax and execution
- APT package installation
- Cargo, pip, npm package management
- chezmoi file deployment
- Template rendering and profile system
- Directory structure
- Script execution
- Manual installations (where possible)

❌ **Not Tested in Docker:**
- GNOME desktop environment
- GNOME extensions
- Snap packages (systemd issues)
- GUI applications
- Desktop themes and appearance
- Display settings
- Keyboard shortcuts

### Running Docker Tests

```bash
# Run Docker test suite
./scripts/test-docker.sh

# Test with work profile
PROFILE=work ./scripts/test-docker.sh
```

**Expected Output:**
- Ansible syntax validation ✓
- Profile system verification ✓
- chezmoi dry run ✓
- Package role validation ✓

**Duration**: ~5 minutes

### Docker Test Results

If Docker tests pass:
- ✅ Core automation works
- ✅ Templates render correctly
- ✅ Package definitions are valid
- ✅ Profile system functions

If Docker tests fail:
- Fix issues before proceeding to VM testing
- Check Ansible syntax
- Verify template variables
- Review package lists

## Phase 2: VM Testing

### What VM Tests

✅ **Full System Test:**
- Everything from Docker tests
- **Plus** GNOME desktop environment
- **Plus** GUI applications
- **Plus** Desktop themes and extensions
- **Plus** System integration
- **Plus** Complete end-to-end workflow

### VM Setup Options

#### Option 1: VirtualBox/VMware
```bash
# 1. Download Ubuntu 22.04 ISO
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso

# 2. Create VM with:
# - 4GB RAM minimum (8GB recommended)
# - 25GB disk minimum
# - Enable clipboard sharing
# - Enable drag-and-drop

# 3. Install Ubuntu with default GNOME
# 4. Take snapshot: "fresh-install"
```

#### Option 2: Cloud VM (DigitalOcean, AWS, etc.)
```bash
# Note: Requires X server forwarding or VNC for GNOME testing
# Not recommended for full testing
```

### Running Full Test in VM

1. **Boot fresh Ubuntu VM**

2. **Clone dotfiles:**
   ```bash
   git clone https://github.com/alexborgognoni/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

3. **Optional - Bitwarden login:**
   ```bash
   # Install bw first if not in packages
   sudo snap install bw
   bw login
   export BW_SESSION=$(bw unlock --raw)
   ```

4. **Run bootstrap:**
   ```bash
   ./install
   # Choose profile when prompted
   ```

5. **Verify everything:**
   ```bash
   # Run automated tests
   ./scripts/test-profile-switching.sh

   # Manual verification checklist below
   ```

### Manual Verification Checklist

After bootstrap completes:

#### Shell & Terminal
- [ ] Open new terminal - zsh is default shell
- [ ] Starship prompt shows correctly
- [ ] Custom aliases work (`ls`, `bat`, `nv`, etc.)
- [ ] Zinit plugins loaded
- [ ] Kitty terminal theme correct

#### Development Tools
- [ ] Neovim opens with config
- [ ] Tmux prefix works (Ctrl+a)
- [ ] Git config correct (`git config --list`)
- [ ] GitHub CLI authenticated (`gh auth status`)

#### GNOME Desktop
- [ ] Extensions installed and enabled
- [ ] Theme applied (check Settings → Appearance)
- [ ] Keyboard shortcuts work:
  - [ ] Super+Return → Terminal
  - [ ] Super+E → Files
  - [ ] Super+Shift+Return → Browser
- [ ] Wallpaper set correctly
- [ ] Icon theme applied
- [ ] Cursor theme applied

#### Package Installation
- [ ] VS Code installed and launches
- [ ] Chrome installed and launches
- [ ] Docker running (`docker ps`)
- [ ] All expected tools in PATH

#### Profile System
- [ ] Correct git email for profile
- [ ] Work-specific settings (if work profile)
- [ ] Profile indicator in prompt

### Test Scenarios

#### Scenario 1: Fresh Personal Machine
```bash
PROFILE=personal ./install
# Verify personal git email
# Verify no work-specific packages
# Verify personal GPG key (if configured)
```

#### Scenario 2: Fresh Work Machine
```bash
PROFILE=work ./install
# Verify work git email
# Verify work-specific packages (Azure CLI, etc.)
# Verify CA cert configuration
```

#### Scenario 3: Profile Switch
```bash
# Initial install with personal
PROFILE=personal ./install

# Switch to work
PROFILE=work chezmoi apply

# Verify configs changed appropriately
```

## Automated Test Scripts

### test-profile-switching.sh
**Purpose**: Validates the profile system
**Tests**: 10 comprehensive tests including dry-run
**Usage**: `./scripts/test-profile-switching.sh`
**Duration**: ~2 minutes

### test-docker.sh
**Purpose**: Validates non-GUI components in Docker
**Tests**: Ansible, chezmoi, packages
**Usage**: `./scripts/test-docker.sh`
**Duration**: ~5 minutes

## Troubleshooting Tests

### Docker Container Won't Build
```bash
# Check Docker service
sudo systemctl status docker

# Clean Docker cache
docker system prune -a

# Rebuild image
docker build --no-cache -t dotfiles-test -f tests/Dockerfile .
```

### Ansible Playbook Fails
```bash
# Check syntax
ansible-playbook ansible/playbook.yml --syntax-check

# Run in check mode
ansible-playbook ansible/playbook.yml --check

# Run with verbose output
ansible-playbook ansible/playbook.yml -vvv
```

### chezmoi Apply Fails
```bash
# Check what would change
chezmoi diff

# Apply with verbose output
chezmoi apply -v

# Check for template errors
chezmoi execute-template < template-file
```

### Package Installation Fails
```bash
# Update package cache
sudo apt update

# Check repository setup
ls -la /etc/apt/sources.list.d/

# Check GPG keys
ls -la /etc/apt/keyrings/

# Test individual package
sudo apt install -y package-name
```

## Test Results Documentation

### Keep Track Of
- Date tested
- Ubuntu version
- Profile tested
- Pass/fail status
- Any issues encountered
- Time to complete

### Example Test Log
```
Date: 2025-01-21
Ubuntu: 22.04.3
Profile: personal
Docker Tests: ✓ PASS (5m)
VM Tests: ✓ PASS (28m)
Issues: None
Notes: All packages installed correctly
```

## Continuous Testing

### Before Committing Changes
1. Run Docker tests: `./scripts/test-docker.sh`
2. Run profile tests: `./scripts/test-profile-switching.sh`
3. Commit if both pass

### After Major Changes
- Test in VM to verify full system
- Test both profiles
- Document any new manual steps

### Quarterly Maintenance
- Test on latest Ubuntu LTS
- Update package versions
- Verify all repositories still work
- Test on fresh VM

## Performance Benchmarks

**Typical Bootstrap Times:**
- Docker tests: 5 minutes
- VM full bootstrap: 20-30 minutes
  - Ansible playbook: 15-20 minutes
  - chezmoi apply: 2-3 minutes
  - Manual verification: 5-10 minutes

**Factors affecting time:**
- Internet connection speed
- Package mirror location
- VM resources
- Number of packages

## Next Steps After Testing

1. ✅ Docker tests pass
2. ✅ VM tests pass
3. ✅ Manual verification complete
4. → Deploy to main machine
5. → Create GitHub release/tag
6. → Update documentation
