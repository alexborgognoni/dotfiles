# Profile System Guide

This guide explains how to manage work vs personal configurations in this dotfiles repository.

## Overview

The profile system allows you to maintain a single dotfiles repository that can be customized for different environments. Currently supported profiles:

- **personal**: Home/personal machine
- **work**: Corporate work machine

## Profile Selection

During bootstrap, you'll be prompted to select a profile:

```bash
./install
# Which profile? [personal/work]: work
```

This sets the `PROFILE` environment variable used by both Ansible and chezmoi.

## Two Types of Profile-Specific Configurations

### 1. Partial File Overrides (Templating)

**Use Case**: Same file exists in both profiles, but with different values.

**Example**: `.zshrc` has different CA certificate settings for work vs personal.

**Implementation**: Use chezmoi templates with conditional blocks.

#### Example: `.zshrc` with work-specific CA certs

```zsh
# chezmoi/dot_zshrc.tmpl

export GOPATH="$HOME/go"

{{- if eq .profile "work" }}
# Work-specific CA certificate configuration
export REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"
export NODE_OPTIONS="--use-openssl-ca --use-system-ca"
{{- end }}

# Rest of the file...
```

When you run with `profile=work`, the CA cert exports are included. With `profile=personal`, they're excluded.

#### Example: `.gitconfig` with different emails

```toml
# chezmoi/dot_gitconfig.tmpl

[user]
	name = {{ .name }}
	email = {{ .email }}  # Comes from .chezmoi.toml.tmpl based on profile
{{- if eq .profile "personal" }}
	signingkey = CDAA1309229CF3B46B7446F221D072CC9982C9BB
{{- end }}

[commit]
{{- if eq .profile "personal" }}
	gpgsign = true
{{- else }}
	gpgsign = false
{{- end }}

{{- if eq .profile "work" }}
[url "ssh://git@github.deutsche-boerse.de/"]
	insteadOf = https://github.deutsche-boerse.de/
{{- end }}
```

#### Creating a Templated File

1. Create the file with `.tmpl` suffix: `dot_filename.tmpl`
2. Add conditional blocks using Go template syntax
3. Variables come from `.chezmoi.toml.tmpl`

**Available Variables**:
- `.profile` - Current profile (personal/work)
- `.email` - User email (profile-specific)
- `.name` - User name
- `.chezmoi.os` - Operating system (linux/darwin/windows)
- `.chezmoi.hostname` - Machine hostname

### 2. Entire Files (Conditional Inclusion)

**Use Case**: File should only exist in one profile.

**Example**: `.Xmodmap` only exists on work laptop for keyboard remapping.

**Implementation**: Use `.chezmoiignore` with conditional logic.

#### Method A: .chezmoiignore (Recommended)

Add the file to `.chezmoiignore` with a profile condition:

```
# chezmoi/.chezmoiignore

{{- if eq .profile "personal" }}
# Ignore work-specific files in personal profile
.Xmodmap  # Only used on work laptop
.config/work/
{{- end }}

{{- if eq .profile "work" }}
# Ignore personal-specific files in work profile
.config/personal/
{{- end }}
```

**How it works**:
1. File `dot_Xmodmap` exists in `chezmoi/` directory
2. When `profile=work`: File is applied to home directory
3. When `profile=personal`: File is ignored (not applied)

**Advantages**:
- Simple and clean
- File exists in repo for the profile that needs it
- No empty files created

#### Method B: Template with Empty Content (Alternative)

Create a template that generates empty content for one profile:

```
# chezmoi/dot_Xmodmap.tmpl

{{- if eq .profile "work" }}
! Xmodmap configuration for work laptop
! Swap Caps Lock and Escape
remove Lock = Caps_Lock
keysym Caps_Lock = Escape
{{- end }}
```

When `profile=personal`, this creates an empty `.Xmodmap` file (or you can use `{{- if eq .profile "work" -}}...{{- end -}}` to create no file at all).

**Disadvantages**:
- May create empty files
- More complex than .chezmoiignore

**Recommendation**: Use Method A (.chezmoiignore) for entire files.

## Practical Examples

### Example 1: pip Configuration

**Requirement**: Work uses Artifactory, personal uses PyPI.

**File**: `~/.config/pip/pip.conf`

**Solution**: Template with conditional values

```ini
# chezmoi/dot_config/pip/pip.conf.tmpl

[global]
{{- if eq .profile "work" }}
index-url = https://artifactory.company.com/artifactory/api/pypi/pypi-remote/simple
extra-index-url = https://pypi.org/simple
{{- else }}
index-url = https://pypi.org/simple
{{- end }}
```

### Example 2: Work-Only Scripts

**Requirement**: Shell scripts only needed at work.

**Files**: `~/bin/work-vpn-connect.sh`, `~/bin/work-auth-refresh.sh`

**Solution**: Use .chezmoiignore

```
# chezmoi/.chezmoiignore

{{- if eq .profile "personal" }}
# Work-only scripts
bin/work-vpn-connect.sh
bin/work-auth-refresh.sh
{{- end }}
```

### Example 3: Different Aliases

**Requirement**: Different aliases for work vs personal.

**File**: `~/.zsh/aliases.zsh`

**Solution**: Template with conditional blocks

```zsh
# chezmoi/dot_zsh/aliases.zsh.tmpl

# Common aliases for all profiles
alias ll='eza -la --icons'
alias vim='nvim'
alias cat='batcat'

{{- if eq .profile "work" }}
# Work-specific aliases
alias vpn='sudo openvpn --config /etc/openvpn/work.conf'
alias kubectl='kubecolor'
alias k='kubectl'
{{- end }}

{{- if eq .profile "personal" }}
# Personal aliases
alias personal-proj='cd ~/projects/personal'
{{- end }}
```

### Example 4: Entire Directory Trees

**Requirement**: Work-specific config directory with multiple files.

**Files**: `~/.config/work/` (entire directory)

**Solution**: Use .chezmoiignore with directory pattern

```
# chezmoi/.chezmoiignore

{{- if eq .profile "personal" }}
.config/work/  # Entire work directory ignored in personal profile
{{- end }}
```

## Ansible Variables

Profile-specific variables are in `ansible/group_vars/`:

```yaml
# ansible/group_vars/work.yml
work_env_vars:
  NODE_EXTRA_CA_CERTS: "/etc/ssl/certs/ca-certificates.crt"
  NODE_OPTIONS: "--use-openssl-ca --use-system-ca"

pip_index_url: "https://artifactory.company.com/..."
```

These variables can be used in Ansible tasks and also influence chezmoi templates via `.chezmoi.toml.tmpl`.

## Best Practices

### 1. Prefer Templates for Partial Differences

If most of the file is the same, use templates:
```
✅ Good: dot_zshrc.tmpl with conditional blocks
❌ Avoid: Separate dot_zshrc_personal and dot_zshrc_work
```

### 2. Use .chezmoiignore for Entire Files

If a file only exists in one profile, use .chezmoiignore:
```
✅ Good: dot_Xmodmap + .chezmoiignore condition
❌ Avoid: dot_Xmodmap.tmpl with empty content
```

### 3. Keep Profiles DRY

Don't duplicate configuration. Extract common parts:
```zsh
# ✅ Good
alias ll='eza -la --icons'  # Common

{{- if eq .profile "work" }}
alias k='kubectl'  # Work-only
{{- end }}

# ❌ Avoid
{{- if eq .profile "work" }}
alias ll='eza -la --icons'  # Duplicated
alias k='kubectl'
{{- end }}

{{- if eq .profile "personal" }}
alias ll='eza -la --icons'  # Duplicated
{{- end }}
```

### 4. Document Profile Differences

Add comments explaining why something is profile-specific:
```zsh
{{- if eq .profile "work" }}
# Work requires custom CA certificates for corporate MITM proxy
export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"
{{- end }}
```

### 5. Test Both Profiles

Before committing, test both profiles:
```bash
# Test personal profile
PROFILE=personal chezmoi diff

# Test work profile
PROFILE=work chezmoi diff
```

## Switching Profiles

To switch an existing system to a different profile:

```bash
# Set new profile
export PROFILE=work

# See what will change
chezmoi diff

# Apply changes
chezmoi apply
```

**Note**: This only changes dotfiles. To run Ansible tasks for the new profile, re-run the bootstrap script or manually run the Ansible playbook with the new profile.

## Template Syntax Reference

### Basic Conditional

```
{{- if eq .profile "work" }}
Work-specific content
{{- end }}
```

### If-Else

```
{{- if eq .profile "work" }}
Work content
{{- else }}
Personal content
{{- end }}
```

### Multiple Conditions

```
{{- if and (eq .profile "work") (eq .chezmoi.os "linux") }}
Work Linux-specific content
{{- end }}
```

### Checking Multiple Values

```
{{- if or (eq .profile "work") (eq .profile "contractor") }}
Content for work and contractor profiles
{{- end }}
```

### Variables

```
{{ .profile }}        # Current profile
{{ .email }}          # User email (from .chezmoi.toml.tmpl)
{{ .name }}           # User name
{{ .chezmoi.os }}     # linux/darwin/windows
{{ .chezmoi.hostname }}  # Machine hostname
```

### Whitespace Control

```
{{- /* Remove whitespace before */ -}}
{{ /* Keep whitespace */ }}
{{- /* Remove whitespace before and after */ -}}
```

## Debugging

### Check Current Profile

```bash
echo $PROFILE
```

### View Evaluated Template

```bash
# See what a template will generate
chezmoi cat ~/.zshrc
```

### Diff Between Profiles

```bash
# Current profile
chezmoi diff

# Different profile
PROFILE=work chezmoi diff
```

### View All Variables

```bash
# See all available template variables
chezmoi data
```

Example output:
```json
{
  "chezmoi": {
    "os": "linux",
    "hostname": "my-laptop"
  },
  "profile": "personal",
  "email": "alex@example.com",
  "name": "Alex"
}
```

## Adding a New Profile

To add a new profile (e.g., "contractor"):

1. Create `ansible/group_vars/contractor.yml`
2. Update `.chezmoi.toml.tmpl` to handle contractor profile
3. Add contractor conditions to templates
4. Update bootstrap script to accept "contractor" as valid profile

## Summary

| Scenario | Solution | Example |
|----------|----------|---------|
| Same file, different values | Template with `{{ if }}` blocks | `.zshrc`, `.gitconfig` |
| File only in one profile | `.chezmoiignore` with condition | `.Xmodmap` (work only) |
| Entire directory for one profile | `.chezmoiignore` directory pattern | `.config/work/` |
| Different values in Ansible | `group_vars/<profile>.yml` | `pip_index_url` |

---

**Next**: See [SECRETS.md](SECRETS.md) for managing secrets across profiles.

## Template Helpers

The profile system includes reusable template helpers to simplify common patterns.

### Available Template Helpers

Located in `chezmoi/.chezmoitemplates/`:

1. **header.tmpl** - Standard file header
   ```
   {{- template "header.tmpl" . -}}
   ```
   Outputs:
   ```
   # This file is managed by chezmoi. DO NOT EDIT MANUALLY.
   # Source: path/to/source/file
   # Profile: personal
   ```

2. **if-personal.tmpl** - Test for personal profile
   ```
   {{- if template "if-personal.tmpl" . -}}
   Personal-only content
   {{- end -}}
   ```

3. **if-work.tmpl** - Test for work profile
   ```
   {{- if template "if-work.tmpl" . -}}
   Work-only content
   {{- end -}}
   ```

4. **profile-block.tmpl** - Include content for specific profile
   ```
   {{- template "profile-block.tmpl" dict "profile" "work" "content" "work code" -}}
   ```

5. **profile-value.tmpl** - Select value based on profile
   ```
   {{- template "profile-value.tmpl" dict "profile" . "personal" "value1" "work" "value2" "default" "value3" -}}
   ```

### Creating Custom Template Helpers

1. Create `.chezmoitemplates/myhelper.tmpl`
2. Define the template logic
3. Use in any `.tmpl` file with `{{ template "myhelper.tmpl" . }}`

Example custom helper:
```
{{- /* .chezmoitemplates/is-laptop.tmpl */ -}}
{{- contains "laptop" .chezmoi.hostname -}}
```

Usage:
```
{{- if template "is-laptop.tmpl" . -}}
# Laptop-specific config
{{- end -}}
```

## Testing Profile Switching

### Automated Testing

Use the provided test script to validate your profile system:

```bash
./scripts/test-profile-switching.sh
```

This tests:
- ✓ PROFILE environment variable
- ✓ Ansible inventory and group_vars
- ✓ Ansible playbook syntax
- ✓ chezmoi configuration
- ✓ Template rendering
- ✓ Template files and helpers
- ✓ Profile-specific differences

Expected output:
```
════════════════════════════════════════════════════════════
                    PROFILE SYSTEM TEST SUITE
════════════════════════════════════════════════════════════

Testing with PROFILE=personal

[TEST 1] Checking PROFILE environment variable
✓ PASS PROFILE=personal

...

Total tests: 10
Passed: 8
Failed: 2  (expected if chezmoi not installed yet)

✓ All tests passed!
```

### Manual Testing

**Test personal profile:**
```bash
export PROFILE=personal
./install
```

**Test work profile:**
```bash
export PROFILE=work
./install
```

**Preview changes with chezmoi:**
```bash
# See what would change
export PROFILE=personal
chezmoi diff --source=~/dotfiles/chezmoi

# Apply changes
chezmoi apply --source=~/dotfiles/chezmoi
```

**Test Ansible with specific profile:**
```bash
cd ~/dotfiles/ansible
ansible-playbook -i inventory.yml playbook.yml \
  -e "profile=personal" \
  --check \
  --diff
```

## Advanced Profile Patterns

### Machine-Specific Overrides

Combine profiles with machine-specific settings:

```
{{- if and (eq .profile "work") (eq .chezmoi.hostname "work-laptop") -}}
# Only on work laptop
{{- end -}}
```

### Environment-Based Profiles

Automatically detect environment:

```toml
# .chezmoi.toml.tmpl
{{- $profile := env "PROFILE" -}}
{{- if not $profile -}}
{{-   /* Auto-detect based on hostname or network */ -}}
{{-   if contains "corp" .chezmoi.hostname -}}
{{-     $profile = "work" -}}
{{-   else -}}
{{-     $profile = "personal" -}}
{{-   end -}}
{{- end -}}

[data]
    profile = {{ $profile | quote }}
```

### Multi-Level Profiles

Extend beyond work/personal:

```
{{- if eq .profile "personal-gaming" -}}
# Gaming-specific settings
{{- else if eq .profile "personal-dev" -}}
# Development-specific settings
{{- end -}}
```

### Encrypted Profile-Specific Secrets

Use Bitwarden or age for profile-specific secrets:

```
{{- if eq .profile "work" -}}
export AWS_ACCESS_KEY="{{ (bitwarden "item" "work-aws").login.password }}"
{{- else -}}
export AWS_ACCESS_KEY="{{ (bitwarden "item" "personal-aws").login.password }}"
{{- end -}}
```

## Troubleshooting

### Profile Not Being Applied

**Problem**: Changes don't reflect the selected profile.

**Solution**:
1. Verify PROFILE environment variable: `echo $PROFILE`
2. Check .chezmoi.toml: `cat ~/.config/chezmoi/chezmoi.toml`
3. Preview template output: `chezmoi execute-template '{{ .profile }}'`
4. Re-run install with correct profile: `PROFILE=work ./install`

### Template Syntax Errors

**Problem**: chezmoi fails with template parsing errors.

**Solution**:
1. Check Go template syntax
2. Test template: `chezmoi execute-template < template-file.tmpl`
3. Common mistakes:
   - Missing `{{-` or `-}}`
   - Unmatched `{{ if }}` without `{{ end }}`
   - Incorrect variable names (`.proflie` instead of `.profile`)

### Profile-Specific File Not Excluded

**Problem**: File appears in wrong profile.

**Solution**:
1. Check `.chezmoiignore` syntax
2. Verify the condition: `{{ if eq .profile "personal" }}`
3. Test: `chezmoi diff --source=~/dotfiles/chezmoi`

### Ansible Uses Wrong Variables

**Problem**: Ansible uses wrong profile variables.

**Solution**:
1. Verify profile passed to Ansible: `ansible-playbook ... -e "profile=personal"`
2. Check group_vars files exist
3. Validate YAML syntax: `yamllint group_vars/`

## Best Practices

1. **Keep profiles simple**: Start with just personal/work
2. **Use templates sparingly**: Only template what actually differs
3. **Document differences**: Add comments explaining profile-specific settings
4. **Test both profiles**: Regularly test both profiles in VMs
5. **Version control everything**: Commit all profile-specific configs
6. **Use meaningful names**: Name variables clearly (`work_proxy_url` not `url1`)
7. **Leverage helpers**: Use template helpers for common patterns
8. **Validate regularly**: Run test script after profile changes

## Profile System Architecture

```
dotfiles/
├── ansible/
│   ├── playbook.yml              # Uses -e "profile=X"
│   └── group_vars/
│       ├── all.yml               # Common to all profiles
│       ├── personal.yml          # Personal profile variables
│       └── work.yml              # Work profile variables
│
├── chezmoi/
│   ├── .chezmoi.toml.tmpl        # Profile selection & variables
│   ├── .chezmoiignore            # Conditional file exclusion
│   ├── .chezmoitemplates/        # Reusable template helpers
│   │   ├── header.tmpl
│   │   ├── if-personal.tmpl
│   │   ├── if-work.tmpl
│   │   └── ...
│   ├── dot_zshrc.tmpl            # Templated config
│   ├── dot_gitconfig.tmpl        # Templated config
│   └── ...
│
├── scripts/
│   └── test-profile-switching.sh # Automated testing
│
└── install                        # Bootstrap with profile prompt
```

## Examples Repository

See real-world examples in the codebase:

- **Basic templating**: `chezmoi/dot_zshrc.tmpl`
- **Email switching**: `chezmoi/dot_gitconfig.tmpl`
- **File exclusion**: `chezmoi/.chezmoiignore`
- **Profile variables**: `ansible/group_vars/work.yml`
- **Conditional packages**: `ansible/roles/packages/vars/work.yml`
- **GNOME favorites**: `ansible/roles/gnome/vars/work.yml`

---

**Remember**: The profile system is designed to be simple and maintainable. Start with obvious differences (email, packages) and add complexity only when needed.
