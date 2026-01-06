# Secrets Role

SSH and GPG key management with Bitwarden integration.

## Purpose

Sets up cryptographic identities:
- SSH key generation or retrieval from Bitwarden
- GPG key generation or retrieval from Bitwarden
- Git signing configuration
- Key trust establishment

## Variables

Keys are defined in profile-specific group_vars:

| Variable | Description |
|----------|-------------|
| `ssh_keys` | List of SSH keys to manage |
| `gpg_keys` | List of GPG keys to manage |

## Tags

- `secrets` - All secrets tasks (can be skipped with `--skip-tags secrets`)

## Skipping

To skip secrets setup:
```bash
SKIP_SECRETS=true ./install
# or
ansible-playbook playbook.yml --skip-tags secrets
```

## Dependencies

- `packages` role (for Bitwarden CLI)
