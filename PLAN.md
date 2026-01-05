# SSH & GPG Keys Setup Plan

## Overview

Automated setup for SSH and GPG keys across personal and work machines, with Bitwarden as the source of truth for key storage.

---

## Key Matrix

| Profile  | Key Type | Filename | Email | Bitwarden Item |
|----------|----------|----------|-------|----------------|
| Personal | SSH | `~/.ssh/id_ed25519` | alex.bor0419@gmail.com | `ssh-personal-github` |
| Personal | GPG | (default) | alex.bor0419@gmail.com | `gpg-personal` |
| Work | SSH | `~/.ssh/id_ed25519` | alex.borgognoni@deutsche-boerse.com | `ssh-work-enterprise` |
| Work | SSH | `~/.ssh/id_ed25519_personal` | alex.bor0419@gmail.com | `ssh-personal-github` |
| Work | GPG | (default) | alex.borgognoni@deutsche-boerse.com | `gpg-work` |
| Work | GPG | (personal) | alex.bor0419@gmail.com | `gpg-personal` |

---

## File Structure

### Personal Machine
```
~/.ssh/
├── config                    # Minimal/empty
├── id_ed25519               # Personal github.com
└── id_ed25519.pub

~/.gnupg/
└── (personal GPG key imported)

~/.gitconfig                 # Personal email + personal GPG signing key
```

### Work Machine
```
~/.ssh/
├── config                    # Routes github.com → personal key
├── id_ed25519               # Work enterprise (default)
├── id_ed25519.pub
├── id_ed25519_personal      # Personal github.com
└── id_ed25519_personal.pub

~/.gnupg/
└── (work + personal GPG keys imported)

~/.gitconfig                 # Work email + work GPG key (default)
~/.gitconfig-personal        # Personal overrides (for ~/Personal/ path)
```

---

## Bitwarden Storage Format

### SSH Keys (Secure Note)
```
Name: ssh-personal-github
Type: Secure Note (type: 2)
Folder: dotfiles-keys

Fields:
  - private_key: (contents of id_ed25519) [type: 1 = hidden]
  - public_key: (contents of id_ed25519.pub) [type: 0 = text]
  - email: alex.bor0419@gmail.com [type: 0 = text]
```

### GPG Keys (Secure Note)
```
Name: gpg-personal
Type: Secure Note (type: 2)
Folder: dotfiles-keys

Fields:
  - private_key: (gpg --export-secret-keys --armor) [type: 1 = hidden]
  - public_key: (gpg --export --armor) [type: 0 = text]
  - key_id: <GPG key fingerprint> [type: 0 = text]
  - email: alex.bor0419@gmail.com [type: 0 = text]
```

---

## Install Script Flow

```
./install [--skip-secrets] [--profile work|personal]

┌─────────────────────────────────────────────────────────────┐
│ 1. Parse arguments                                          │
│    └── Check for --skip-secrets flag                        │
├─────────────────────────────────────────────────────────────┤
│ 2. If --skip-secrets NOT provided:                          │
│    └── Prompt: "Set up SSH/GPG keys? [Y/n]"                 │
│        ├── Y/yes (default) → Continue with secrets          │
│        └── n/no → Set SKIP_SECRETS=true                     │
├─────────────────────────────────────────────────────────────┤
│ 3. Run ansible-playbook with appropriate tags               │
│    └── If SKIP_SECRETS: add --skip-tags secrets             │
└─────────────────────────────────────────────────────────────┘
```

---

## Bitwarden Automation Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Check if `bw` CLI installed                              │
│    └── Already installed via manual.yml (native download)   │
│        from https://vault.bitwarden.com/download/           │
├─────────────────────────────────────────────────────────────┤
│ 2. Check login status: `bw status`                          │
│    Returns JSON: {"status": "unauthenticated|locked|unlocked"}
│    └── If "unauthenticated":                                │
│        └── Run `bw login` (interactive email/password)      │
├─────────────────────────────────────────────────────────────┤
│ 3. Unlock vault: `bw unlock --raw`                          │
│    └── Prompts for master password                          │
│    └── Returns BW_SESSION token (export as env var)         │
├─────────────────────────────────────────────────────────────┤
│ 4. Ensure folder exists: "dotfiles-keys"                    │
│    └── `bw get folder dotfiles-keys` or create it           │
├─────────────────────────────────────────────────────────────┤
│ 5. For each key (based on profile):                         │
│    ├── Check: `bw get item "<bw_name>"`                     │
│    │   ├── Found (rc=0) →                                   │
│    │   │   ├── Extract private_key field                    │
│    │   │   ├── Extract public_key field                     │
│    │   │   └── Write to disk with correct permissions       │
│    │   │                                                    │
│    │   └── Not found (rc!=0) →                              │
│    │       ├── Prompt for passphrase (SSH only)             │
│    │       ├── Generate key (ssh-keygen or gpg)             │
│    │       ├── Write to disk                                │
│    │       ├── Create Bitwarden item with fields            │
│    │       └── Print public key for GitHub setup            │
├─────────────────────────────────────────────────────────────┤
│ 6. Import GPG keys into keyring                             │
│    └── `gpg --import <private_key>`                         │
│    └── Set trust level to ultimate                          │
├─────────────────────────────────────────────────────────────┤
│ 7. Lock vault: `bw lock`                                    │
├─────────────────────────────────────────────────────────────┤
│ 8. Display summary                                          │
│    └── List public keys to add to GitHub                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Bitwarden CLI Commands Reference

### Check Status
```bash
bw status
# Returns: {"serverUrl":"...","lastSync":"...","status":"unauthenticated|locked|unlocked"}
```

### Login (first time)
```bash
bw login
# Interactive: prompts for email, password, 2FA
# Stores session locally
```

### Unlock Vault
```bash
export BW_SESSION=$(bw unlock --raw)
# Prompts for master password
# Returns session token
```

### Check if Item Exists
```bash
bw get item "ssh-personal-github" --session "$BW_SESSION"
# Returns JSON if found, exit code 1 if not found
```

### Extract Field from Item
```bash
bw get item "ssh-personal-github" --session "$BW_SESSION" | \
  jq -r '.fields[] | select(.name=="private_key") | .value'
```

### Create Secure Note with Fields
```bash
# Get folder ID first
FOLDER_ID=$(bw get folder "dotfiles-keys" --session "$BW_SESSION" | jq -r '.id')

# Create item
echo '{
  "type": 2,
  "name": "ssh-personal-github",
  "folderId": "'"$FOLDER_ID"'",
  "notes": "",
  "secureNote": {"type": 0},
  "fields": [
    {"name": "private_key", "value": "'"$(cat ~/.ssh/id_ed25519)"'", "type": 1},
    {"name": "public_key", "value": "'"$(cat ~/.ssh/id_ed25519.pub)"'", "type": 0},
    {"name": "email", "value": "alex.bor0419@gmail.com", "type": 0}
  ]
}' | bw encode | bw create item --session "$BW_SESSION"
```

### Create Folder
```bash
echo '{"name": "dotfiles-keys"}' | bw encode | bw create folder --session "$BW_SESSION"
```

### Lock Vault
```bash
bw lock
```

---

## Implementation Details

### 1. New Ansible Role: `secrets`

```
ansible/roles/secrets/
├── tasks/
│   ├── main.yml           # Entry point, orchestrates flow
│   ├── bitwarden.yml      # BW status/login/unlock
│   ├── ssh.yml            # SSH key generation/retrieval
│   └── gpg.yml            # GPG key generation/retrieval/import
├── templates/
│   └── gpg-key-params.j2  # GPG batch generation parameters
└── defaults/
    └── main.yml           # Default values
```

### 2. Profile Variables

```yaml
# group_vars/personal.yml
personal_email: "alex.bor0419@gmail.com"
personal_name: "Alex Borgognoni"

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
# group_vars/work.yml
work_email: "alex.borgognoni@deutsche-boerse.com"
work_name: "Alex Borgognoni"
personal_email: "alex.bor0419@gmail.com"
personal_name: "Alex Borgognoni"

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

### 3. Main Tasks (main.yml)

```yaml
---
# roles/secrets/tasks/main.yml
- name: Set up Bitwarden session
  include_tasks: bitwarden.yml
  tags: ['secrets']

- name: Prompt for SSH key passphrase
  pause:
    prompt: "Enter passphrase for SSH keys (leave empty for no passphrase)"
    echo: no
  register: ssh_passphrase_prompt
  tags: ['secrets']

- name: Set SSH passphrase fact
  set_fact:
    ssh_passphrase: "{{ ssh_passphrase_prompt.user_input | default('') }}"
  tags: ['secrets']

- name: Set up SSH keys
  include_tasks: ssh.yml
  loop: "{{ ssh_keys }}"
  loop_control:
    loop_var: ssh_key
  tags: ['secrets']

- name: Set up GPG keys
  include_tasks: gpg.yml
  loop: "{{ gpg_keys }}"
  loop_control:
    loop_var: gpg_key
  tags: ['secrets']

- name: Lock Bitwarden vault
  command: bw lock
  changed_when: false
  tags: ['secrets']

- name: Display setup summary
  debug:
    msg: |
      ============================================
      SSH/GPG Keys Setup Complete!
      ============================================

      Add these public keys to GitHub:

      {% for key in ssh_keys %}
      {{ key.name }} SSH key ({{ key.email }}):
        {{ lookup('file', key.path + '.pub') }}

      {% endfor %}
      {% for key in gpg_keys %}
      {{ key.name }} GPG key: Run `gpg --armor --export {{ key.email }}`
      {% endfor %}
  tags: ['secrets']
```

### 4. Bitwarden Tasks (bitwarden.yml)

```yaml
---
# roles/secrets/tasks/bitwarden.yml
- name: Check Bitwarden CLI is installed
  command: which bw
  register: bw_installed
  changed_when: false
  failed_when: bw_installed.rc != 0

- name: Get Bitwarden status
  command: bw status
  register: bw_status_result
  changed_when: false

- name: Parse Bitwarden status
  set_fact:
    bw_status: "{{ bw_status_result.stdout | from_json }}"

- name: Login to Bitwarden
  command: bw login
  when: bw_status.status == 'unauthenticated'
  register: bw_login_result

- name: Unlock Bitwarden vault
  command: bw unlock --raw
  register: bw_unlock_result
  when: bw_status.status == 'locked' or bw_login_result is changed

- name: Get session from already unlocked vault
  command: bw unlock --raw
  register: bw_session_result
  when: bw_status.status == 'unlocked'
  changed_when: false

- name: Set Bitwarden session fact
  set_fact:
    bw_session: "{{ bw_unlock_result.stdout | default(bw_session_result.stdout) }}"

- name: Ensure dotfiles-keys folder exists
  block:
    - name: Check if folder exists
      command: bw get folder "dotfiles-keys"
      environment:
        BW_SESSION: "{{ bw_session }}"
      register: folder_check
      ignore_errors: yes
      changed_when: false

    - name: Create folder if not exists
      shell: |
        echo '{"name": "dotfiles-keys"}' | bw encode | bw create folder
      environment:
        BW_SESSION: "{{ bw_session }}"
      when: folder_check.rc != 0
```

### 5. SSH Tasks (ssh.yml)

```yaml
---
# roles/secrets/tasks/ssh.yml
- name: "SSH {{ ssh_key.name }}: Check if key exists in Bitwarden"
  command: bw get item "{{ ssh_key.bw_name }}"
  environment:
    BW_SESSION: "{{ bw_session }}"
  register: bw_ssh_result
  ignore_errors: yes
  changed_when: false

- name: "SSH {{ ssh_key.name }}: Key exists - retrieve from Bitwarden"
  block:
    - name: Extract private key
      set_fact:
        ssh_private_key: "{{ (bw_ssh_result.stdout | from_json).fields | selectattr('name', 'eq', 'private_key') | map(attribute='value') | first }}"
        ssh_public_key: "{{ (bw_ssh_result.stdout | from_json).fields | selectattr('name', 'eq', 'public_key') | map(attribute='value') | first }}"

    - name: Write private key
      copy:
        content: "{{ ssh_private_key }}"
        dest: "{{ ssh_key.path }}"
        mode: '0600'

    - name: Write public key
      copy:
        content: "{{ ssh_public_key }}"
        dest: "{{ ssh_key.path }}.pub"
        mode: '0644'
  when: bw_ssh_result.rc == 0

- name: "SSH {{ ssh_key.name }}: Key not found - generate new key"
  block:
    - name: Generate SSH key
      command: ssh-keygen -t ed25519 -C "{{ ssh_key.email }}" -f "{{ ssh_key.path }}" -N "{{ ssh_passphrase }}"
      args:
        creates: "{{ ssh_key.path }}"

    - name: Get folder ID
      shell: bw get folder "dotfiles-keys" | jq -r '.id'
      environment:
        BW_SESSION: "{{ bw_session }}"
      register: folder_id_result
      changed_when: false

    - name: Upload SSH key to Bitwarden
      shell: |
        cat << 'BWJSON' | bw encode | bw create item
        {
          "type": 2,
          "name": "{{ ssh_key.bw_name }}",
          "folderId": "{{ folder_id_result.stdout }}",
          "notes": "SSH key for {{ ssh_key.email }}",
          "secureNote": {"type": 0},
          "fields": [
            {"name": "private_key", "value": {{ lookup('file', ssh_key.path) | to_json }}, "type": 1},
            {"name": "public_key", "value": {{ lookup('file', ssh_key.path + '.pub') | to_json }}, "type": 0},
            {"name": "email", "value": "{{ ssh_key.email }}", "type": 0}
          ]
        }
        BWJSON
      environment:
        BW_SESSION: "{{ bw_session }}"

    - name: Display new public key
      debug:
        msg: |
          NEW SSH KEY GENERATED: {{ ssh_key.bw_name }}
          Add this public key to GitHub:
          {{ lookup('file', ssh_key.path + '.pub') }}
  when: bw_ssh_result.rc != 0
```

### 6. GPG Tasks (gpg.yml)

```yaml
---
# roles/secrets/tasks/gpg.yml
- name: "GPG {{ gpg_key.name }}: Check if key exists in Bitwarden"
  command: bw get item "{{ gpg_key.bw_name }}"
  environment:
    BW_SESSION: "{{ bw_session }}"
  register: bw_gpg_result
  ignore_errors: yes
  changed_when: false

- name: "GPG {{ gpg_key.name }}: Key exists - retrieve and import"
  block:
    - name: Extract private key
      set_fact:
        gpg_private_key: "{{ (bw_gpg_result.stdout | from_json).fields | selectattr('name', 'eq', 'private_key') | map(attribute='value') | first }}"

    - name: Import GPG key
      shell: echo "{{ gpg_private_key }}" | gpg --import --batch
      register: gpg_import
      changed_when: "'imported' in gpg_import.stderr"

    - name: Get key ID
      set_fact:
        gpg_key_id: "{{ (bw_gpg_result.stdout | from_json).fields | selectattr('name', 'eq', 'key_id') | map(attribute='value') | first }}"

    - name: Trust the key
      shell: echo -e "5\ny\n" | gpg --command-fd 0 --expert --edit-key "{{ gpg_key_id }}" trust
      changed_when: false
  when: bw_gpg_result.rc == 0

- name: "GPG {{ gpg_key.name }}: Key not found - generate new key"
  block:
    - name: Create GPG key parameters file
      copy:
        content: |
          %no-protection
          Key-Type: eddsa
          Key-Curve: ed25519
          Subkey-Type: ecdh
          Subkey-Curve: cv25519
          Name-Real: {{ gpg_key.name_real }}
          Name-Email: {{ gpg_key.email }}
          Expire-Date: 0
          %commit
        dest: "/tmp/gpg-key-params-{{ gpg_key.name }}"
        mode: '0600'

    - name: Generate GPG key
      command: gpg --batch --generate-key "/tmp/gpg-key-params-{{ gpg_key.name }}"

    - name: Get new key ID
      shell: gpg --list-secret-keys --keyid-format=long "{{ gpg_key.email }}" | grep sec | head -1 | awk '{print $2}' | cut -d'/' -f2
      register: new_gpg_key_id
      changed_when: false

    - name: Export private key
      command: gpg --export-secret-keys --armor "{{ gpg_key.email }}"
      register: gpg_private_export

    - name: Export public key
      command: gpg --export --armor "{{ gpg_key.email }}"
      register: gpg_public_export

    - name: Get folder ID
      shell: bw get folder "dotfiles-keys" | jq -r '.id'
      environment:
        BW_SESSION: "{{ bw_session }}"
      register: folder_id_result
      changed_when: false

    - name: Upload GPG key to Bitwarden
      shell: |
        cat << 'BWJSON' | bw encode | bw create item
        {
          "type": 2,
          "name": "{{ gpg_key.bw_name }}",
          "folderId": "{{ folder_id_result.stdout }}",
          "notes": "GPG key for {{ gpg_key.email }}",
          "secureNote": {"type": 0},
          "fields": [
            {"name": "private_key", "value": {{ gpg_private_export.stdout | to_json }}, "type": 1},
            {"name": "public_key", "value": {{ gpg_public_export.stdout | to_json }}, "type": 0},
            {"name": "key_id", "value": "{{ new_gpg_key_id.stdout }}", "type": 0},
            {"name": "email", "value": "{{ gpg_key.email }}", "type": 0}
          ]
        }
        BWJSON
      environment:
        BW_SESSION: "{{ bw_session }}"

    - name: Clean up params file
      file:
        path: "/tmp/gpg-key-params-{{ gpg_key.name }}"
        state: absent

    - name: Display new public key
      debug:
        msg: |
          NEW GPG KEY GENERATED: {{ gpg_key.bw_name }}
          Key ID: {{ new_gpg_key_id.stdout }}
          Add this public key to GitHub:
          {{ gpg_public_export.stdout }}
  when: bw_gpg_result.rc != 0
```

---

## Chezmoi Templates

### ~/.ssh/config
```
{{- if eq .profile "work" }}
# Personal GitHub (uses non-default key)
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes

# Work enterprise uses default key (~/.ssh/id_ed25519)
Host github.deutsche-boerse.de
    HostName github.deutsche-boerse.de
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
{{- end }}
```

### ~/.gitconfig
```
[user]
{{- if eq .profile "personal" }}
    name = Alex Borgognoni
    email = alex.bor0419@gmail.com
    signingkey = {{ .gpg_key_personal }}
{{- else }}
    name = Alex Borgognoni
    email = alex.borgognoni@deutsche-boerse.com
    signingkey = {{ .gpg_key_work }}
{{- end }}

[commit]
    gpgsign = true

[init]
    defaultBranch = main

[pull]
    rebase = false

{{- if eq .profile "work" }}
[includeIf "gitdir:~/Personal/"]
    path = ~/.gitconfig-personal
{{- end }}
```

### ~/.gitconfig-personal (work profile only)
```
{{- if eq .profile "work" }}
[user]
    email = alex.bor0419@gmail.com
    signingkey = {{ .gpg_key_personal }}
{{- end }}
```

---

## Install Script Updates

```bash
#!/bin/bash
# install

set -e

SKIP_SECRETS=false
PROFILE="${PROFILE:-personal}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-secrets)
            SKIP_SECRETS=true
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./install [--skip-secrets] [--profile work|personal]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

export PROFILE

# Interactive secrets prompt (if not skipped via flag)
if [[ "$SKIP_SECRETS" != "true" ]]; then
    read -p "Set up SSH/GPG keys? [Y/n] " -r REPLY
    REPLY=${REPLY:-Y}
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        SKIP_SECRETS=true
    fi
fi

# Build ansible command
ANSIBLE_CMD="ansible-playbook playbook.yml -e profile=$PROFILE -K"

if [[ "$SKIP_SECRETS" == "true" ]]; then
    ANSIBLE_CMD="$ANSIBLE_CMD --skip-tags secrets"
fi

echo "Running: $ANSIBLE_CMD"
cd "$(dirname "$0")/ansible"
$ANSIBLE_CMD
```

---

## Execution Order in Playbook

```yaml
roles:
  - base
  - packages
  - secrets      # NEW - tagged with 'secrets'
  - gnome
```

---

## Manual Steps After First Run

1. **Add SSH public keys to GitHub:**
   - Personal: https://github.com/settings/keys
   - Work enterprise: https://github.deutsche-boerse.de/settings/keys

2. **Add GPG public keys to GitHub:**
   - Personal: https://github.com/settings/gpg
   - Work enterprise: https://github.deutsche-boerse.de/settings/gpg

---

## Security Considerations

- Private keys stored with 600 permissions
- GPG keys generated without passphrase (protected by Bitwarden + disk encryption)
- SSH passphrase prompted (can be empty)
- Bitwarden session token only lives for duration of script
- Vault locked after secrets setup
- No secrets stored in git/chezmoi (only templates with placeholders)

---

## Testing Checklist

- [ ] Fresh personal machine: generate new keys, upload to BW
- [ ] Fresh work machine: generate new keys, upload to BW
- [ ] Existing keys in Bitwarden: retrieval works
- [ ] --skip-secrets flag skips secrets role
- [ ] Interactive "n" skips secrets role
- [ ] GPG signing works after setup
- [ ] SSH authentication works after setup
- [ ] Git conditional includes work (work profile ~/Personal/)
- [ ] Bitwarden vault is locked after completion
