# Secret Management

This guide covers SSH/GPG key management via Bitwarden and the secrets Ansible role.

## Overview

The secrets system handles:
- **SSH keys** - Generated or retrieved from Bitwarden
- **GPG keys** - Generated or retrieved from Bitwarden
- **Git signing** - Automatic configuration for commit signing

## Quick Start

### 1. Login to Bitwarden

```bash
bw login
export BW_SESSION=$(bw unlock --raw)
```

### 2. Run Bootstrap

```bash
./install
# When prompted, choose to set up SSH/GPG keys
```

### 3. Skip Secrets (Optional)

```bash
# Skip secrets setup entirely
SKIP_SECRETS=true ./install

# Or via flag
./install --skip-secrets
```

## How It Works

### Secrets Role Flow

```
1. Bitwarden Session Setup
   └── Verify BW_SESSION is set

2. SSH Key Setup (per key in profile)
   ├── Check if key exists in Bitwarden
   ├── If exists: Extract and write to disk
   └── If not: Generate new key, upload to Bitwarden

3. GPG Key Setup (per key in profile)
   ├── Check if key exists in Bitwarden
   ├── If exists: Import from Bitwarden
   └── If not: Generate new key, upload to Bitwarden

4. Git Signing Configuration
   └── Configure git to sign commits with GPG key

5. Lock Bitwarden Vault
```

### Profile Configuration

Keys are defined per-profile in `ansible/group_vars/`:

```yaml
# personal.yml
ssh_keys:
  - name: "default"
    bw_name: "ssh-personal-github"
    path: "{{ ansible_env.HOME }}/.ssh/id_ed25519"
    email: "{{ personal_email }}"

gpg_keys:
  - name: "default"
    bw_name: "gpg-personal"
    email: "{{ personal_email }}"
    name_real: "{{ personal_name }}"
```

```yaml
# work.yml
ssh_keys:
  - name: "default"
    bw_name: "ssh-work-enterprise"
    path: "{{ ansible_env.HOME }}/.ssh/id_ed25519"
    email: "{{ work_email }}"
  - name: "personal"
    bw_name: "ssh-personal-github"
    path: "{{ ansible_env.HOME }}/.ssh/id_ed25519_personal"
    email: "{{ personal_email }}"

gpg_keys:
  - name: "default"
    bw_name: "gpg-work"
    email: "{{ work_email }}"
    name_real: "{{ work_name }}"
  - name: "personal"
    bw_name: "gpg-personal"
    email: "{{ personal_email }}"
    name_real: "{{ personal_name }}"
```

## Bitwarden Item Structure

### SSH Keys

Store in Bitwarden as a Secure Note:
- **Name**: `ssh-personal-github` (matches `bw_name`)
- **Notes**: Private key content (full PEM format)
- **Custom Field** `public_key`: Public key content

### GPG Keys

Store in Bitwarden as a Secure Note:
- **Name**: `gpg-personal` (matches `bw_name`)
- **Notes**: ASCII-armored private key (`gpg --armor --export-secret-keys`)
- **Custom Field** `public_key`: ASCII-armored public key

## Commands

### Bitwarden Session

```bash
# Login (one-time)
bw login

# Unlock vault (required before bootstrap)
export BW_SESSION=$(bw unlock --raw)

# Check status
bw status

# Lock vault
bw lock
```

### Manual Key Export

```bash
# Export SSH public key
cat ~/.ssh/id_ed25519.pub

# Export GPG public key for GitHub
gpg --armor --export your@email.com

# Export GPG private key for Bitwarden backup
gpg --armor --export-secret-keys your@email.com
```

### Run Secrets Role Only

```bash
cd ansible
ansible-playbook playbook.yml -e "profile=personal" --tags secrets
```

### Skip Secrets Role

```bash
cd ansible
ansible-playbook playbook.yml -e "profile=personal" --skip-tags secrets
```

## Git Signing

The secrets role automatically configures:

```ini
[user]
    signingkey = <GPG_KEY_ID>

[commit]
    gpgsign = true
```

For work profile with multiple identities, it also creates `~/.gitconfig-personal` for personal repos.

## Troubleshooting

### "Bitwarden vault is locked"

```bash
export BW_SESSION=$(bw unlock --raw)
```

### "Item not found in Bitwarden"

The key will be generated locally and uploaded to Bitwarden.

### "GPG key already exists"

The existing key is used. To regenerate, delete the key first:
```bash
gpg --delete-secret-keys your@email.com
gpg --delete-keys your@email.com
```

### SSH key permissions

Keys are automatically set to correct permissions:
- Private key: `600`
- Public key: `644`
- `.ssh` directory: `700`

## Security Notes

- **Master password**: Never stored, always prompted
- **Session keys**: Temporary, expire on inactivity
- **Private keys**: Only stored in Bitwarden and locally
- **Vault locked**: Automatically locked after secrets setup

## Adding Keys to Services

After setup, add public keys to:

**GitHub (Personal)**
- SSH: https://github.com/settings/keys
- GPG: https://github.com/settings/gpg

**GitHub Enterprise (Work)**
- SSH: https://github.yourcompany.com/settings/keys
- GPG: https://github.yourcompany.com/settings/gpg

---

**Next**: See [TESTING.md](TESTING.md) for testing the complete setup.
