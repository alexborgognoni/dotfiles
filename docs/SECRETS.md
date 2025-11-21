# Secret Management with Bitwarden

This guide explains how to manage secrets (passwords, API tokens, SSH keys) using Bitwarden CLI integration with chezmoi.

## Overview

Secrets are managed using:
- **Bitwarden CLI** (`bw`) for storing and retrieving secrets
- **chezmoi's Bitwarden integration** for templating secrets into configs
- **Interactive authentication** during bootstrap (master password never stored)

## Initial Setup

### 1. Install Bitwarden CLI

The bootstrap script automatically installs Bitwarden CLI to `/usr/local/bin/bw`.

### 2. Login to Bitwarden

Before running the bootstrap, login to Bitwarden:

```bash
# Login (one-time setup per machine)
bw login

# You'll be prompted for:
# - Email address
# - Master password
# - 2FA/OTP code (if enabled)
```

### 3. Unlock and Get Session Key

Before running `./install` or `chezmoi apply`:

```bash
# Unlock vault and export session key
export BW_SESSION=$(bw unlock --raw)

# Alternative: manual unlock and copy session
bw unlock
# Then export the session key shown
```

**Important**: The session key expires after a period of inactivity. You'll need to unlock again when it expires.

## Using Secrets in Templates

chezmoi provides several template functions to retrieve secrets from Bitwarden:

### Get Password from Item

```go
{{- /* Get password from Bitwarden item */ -}}
{{ (bitwarden "item-id").login.password }}
```

### Get Username from Item

```go
{{- /* Get username from Bitwarden item */ -}}
{{ (bitwarden "item-id").login.username }}
```

### Get Custom Field

```go
{{- /* Get custom field from Bitwarden item */ -}}
{{ (bitwardenFields "item-id").fieldName.value }}
```

### Get Secure Note

```go
{{- /* Get secure note content */ -}}
{{ (bitwarden "item-id").notes }}
```

## Finding Item IDs

To find the ID of a Bitwarden item:

```bash
# Ensure you're logged in and unlocked
export BW_SESSION=$(bw unlock --raw)

# List all items
bw list items

# Search for specific item
bw list items --search "github"

# Get item by name
bw get item "GitHub Personal Token"
```

The `id` field in the output is what you use in templates.

## Example: Storing API Tokens

### 1. Store in Bitwarden

Create a new item in Bitwarden:
- **Type**: Login or Secure Note
- **Name**: "GitHub Personal Token"
- **Custom Fields**: Add a field named "token" with your API token

### 2. Use in Template

```zsh
# chezmoi/dot_zshrc.tmpl
{{- /* GitHub API token from Bitwarden */ -}}
export GITHUB_TOKEN="{{ (bitwardenFields "item-id").token.value }}"
```

## Workflow

### Initial Bootstrap on New Machine

```bash
# 1. Clone dotfiles
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Login to Bitwarden
bw login

# 3. Unlock and get session
export BW_SESSION=$(bw unlock --raw)

# 4. Run bootstrap
./install
```

### Regular Updates

```bash
# Unlock Bitwarden
export BW_SESSION=$(bw unlock --raw)

# Apply dotfiles (will fetch secrets)
chezmoi apply
```

### Session Management

```bash
# Check login status
bw status

# Lock vault (destroy session)
bw lock

# Logout completely
bw logout
```

## Security Best Practices

### ✅ DO

- **Keep master password in your head only** - Never write it down digitally
- **Use 2FA** on your Bitwarden account
- **Lock vault** when away from computer: `bw lock`
- **Set session timeout** in Bitwarden settings
- **Use strong master password** (randomly generated, 20+ characters)
- **Review vault regularly** for outdated/unused secrets

### ❌ DON'T

- **Don't commit secrets** to git (even in private repos)
- **Don't store master password** in environment variables
- **Don't put master password** in GitHub secrets
- **Don't share session keys** between machines
- **Don't skip 2FA** - always enable it
- **Don't use weak master password** - this is your single point of failure

## Troubleshooting

### Session Expired

```bash
# Error: "You are not logged in"
export BW_SESSION=$(bw unlock --raw)
```

### Not Logged In

```bash
# Error: "User not logged in"
bw login
```

### Can't Find Item

```bash
# Make sure you're unlocked
bw unlock

# Sync with server
bw sync

# List items to find correct ID
bw list items --search "item-name"
```

### Template Errors

If chezmoi fails with Bitwarden errors:

```bash
# Check Bitwarden status
bw status

# Verify session is set
echo $BW_SESSION

# Test getting item directly
bw get item "item-id"
```

## Alternative: Local Overrides (Without Bitwarden)

For secrets you don't want in Bitwarden, use local override files:

```bash
# Create local secret file (not tracked)
echo 'export SECRET_TOKEN="value"' > ~/.env.local

# Source in .zshrc
[ -f "$HOME/.env.local" ] && source "$HOME/.env.local"
```

Add `~/.env.local` to `.gitignore` and `.chezmoiignore`.

## Common Secrets to Store

### Development
- GitHub Personal Access Token
- npm auth token
- PyPI credentials
- Docker registry credentials

### Cloud Providers
- AWS Access Key ID / Secret
- Azure credentials
- Google Cloud credentials

### APIs
- Slack webhooks
- Discord bot tokens
- API keys for external services

### SSH/GPG
- SSH private key passphrases
- GPG key passphrases
- Certificate passwords

## Notes

- Session keys are temporary and expire - you'll need to re-unlock periodically
- `bw` CLI requires an active internet connection to sync
- First sync after login may take a moment
- chezmoi caches Bitwarden responses during a single run for performance
