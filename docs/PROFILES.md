# Profile System Guide

Manage work vs personal configurations from a single dotfiles repository.

## Overview

The profile system supports two configurations:
- **personal**: Home/personal machine
- **work**: Corporate work machine

## Quick Start

### Profile Selection

```bash
./install
# Prompts: Which profile? [personal/work]:
```

Or set directly:
```bash
PROFILE=work ./install
```

### Switch Profiles

```bash
export PROFILE=work
chezmoi apply
```

## How It Works

### 1. Ansible Variables

Profile-specific variables in `ansible/group_vars/`:

```yaml
# ansible/group_vars/personal.yml
user_email: "alex@gmail.com"
workspace_names: "{'1': 'Terminal', '2': 'Browser'}"

# ansible/group_vars/work.yml
user_email: "alex@company.com"
workspace_names: "{'1': 'Terminal', '2': 'Browser', '3': 'Teams', '4': 'Mail'}"
```

### 2. chezmoi Templates

Templates use Go conditionals based on `.profile`:

```go
// chezmoi/dot_gitconfig.tmpl
[user]
    email = {{ .email }}
{{- if eq .profile "work" }}
[url "ssh://git@github.company.com/"]
    insteadOf = https://github.company.com/
{{- end }}
```

### 3. File Exclusion

Use `.chezmoiignore` to exclude files per profile:

```
# chezmoi/.chezmoiignore
{{- if eq .profile "personal" }}
.Xmodmap
.config/work/
{{- end }}
```

## Template Variables

Available in all `.tmpl` files:

| Variable | Description |
|----------|-------------|
| `.profile` | Current profile (personal/work) |
| `.email` | Profile-specific email |
| `.name` | User name |
| `.chezmoi.os` | Operating system |
| `.chezmoi.hostname` | Machine hostname |

## Template Helpers

Located in `chezmoi/.chezmoitemplates/`:

| Helper | Usage |
|--------|-------|
| `header.tmpl` | Standard "managed by chezmoi" header |
| `if-personal.tmpl` | Check for personal profile |
| `if-work.tmpl` | Check for work profile |
| `profile-block.tmpl` | Conditional content block |
| `profile-value.tmpl` | Select value by profile |

## Testing

### Automated

```bash
./scripts/test-profile-switching.sh
```

Tests 11 aspects including:
- PROFILE environment variable
- Ansible inventory and group_vars
- Ansible playbook syntax
- Secrets skip functionality
- chezmoi configuration and templates
- Profile-specific differences

### Manual

```bash
# Preview changes
PROFILE=personal chezmoi diff

# Test Ansible (dry run)
cd ansible
ansible-playbook playbook.yml -e "profile=work" --check --diff
```

## Debugging

```bash
# Check current profile
echo $PROFILE

# View chezmoi variables
chezmoi data

# Preview template output
chezmoi cat ~/.zshrc

# Compare profiles
PROFILE=personal chezmoi diff
PROFILE=work chezmoi diff
```

## Adding a New Profile

1. Create `ansible/group_vars/newprofile.yml`
2. Update `chezmoi/.chezmoi.toml.tmpl` to handle new profile
3. Add conditions to templates as needed
4. Update install script validation

## Best Practices

1. **Use templates for partial differences** - Same file, different values
2. **Use .chezmoiignore for entire files** - File only exists in one profile
3. **Keep profiles DRY** - Don't duplicate common configuration
4. **Document why** - Comment profile-specific settings
5. **Test both profiles** - Run test script after changes

## Common Patterns

### Conditional Environment Variables

```go
{{- if eq .profile "work" }}
export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"
{{- end }}
```

### Profile-Specific Packages

```yaml
# ansible/roles/packages/vars/work.yml
apt_packages:
  - name: azure-cli
  - name: teams-for-linux
```

### Different Git Identities

```go
[user]
    name = {{ .name }}
    email = {{ .email }}
    signingkey = {{ if eq .profile "work" }}WORK_KEY{{ else }}PERSONAL_KEY{{ end }}
```

---

**Next**: See [SECRETS.md](SECRETS.md) for managing SSH/GPG keys with Bitwarden.
