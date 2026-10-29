#!/usr/bin/env bash
# Remove stale leftovers in /etc that nothing uses and Nix does not own:
# apt backups (*.save, trusted.gpg~, the May 2026 backup directory), the
# PostgreSQL repository (that tool family now runs per project) and the
# signing keys of repositories that no longer exist. Corporate agents
# (Zscaler, CrowdStrike, Intune, cron agents), drivers and the files that
# system-manager restores on deactivation are left alone.
#
#   scripts/cleanup-etc.sh            dry run: lists what would go
#   scripts/cleanup-etc.sh --apply    removes it (needs sudo; /etc is also in
#                                     the snapshot in ~/Backups)
set -euo pipefail

apply=false
[ "${1:-}" = "--apply" ] && apply=true

stale=(
  /etc/apt/sources.list.save
  /etc/apt/trusted.gpg~
  /etc/apt/backup-20260507-095031
  # PostgreSQL repository and key
  /etc/apt/sources.list.d/pgdg.list
  /etc/apt/keyrings/postgresql.gpg
  # keys of repositories that are gone (nothing from them is installed)
  /etc/apt/keyrings/ansible.gpg
  /etc/apt/keyrings/cloudfoundry.asc
  /etc/apt/keyrings/deadsnakes.gpg
  /etc/apt/keyrings/foliate.gpg
  /etc/apt/keyrings/gierens.gpg
  /etc/apt/keyrings/githubcli-archive-keyring.gpg
  /etc/apt/keyrings/hashicorp-archive-keyring.gpg
  /etc/apt/keyrings/microsoft-edge.gpg # Edge's repository uses /usr/share/keyrings
  /etc/apt/keyrings/microsoft-vscode.gpg
  /etc/apt/keyrings/touchegg.gpg
)
# every *.save of apt sources and keys, and editor backups of keys
mapfile -t found < <(find /etc/apt -path /etc/apt/backup-20260507-095031 -prune -o \( -name '*.save' -o -name '*.gpg~' \) -print 2>/dev/null)
stale+=("${found[@]}")

present=()
while IFS= read -r f; do
  [ -e "$f" ] && present+=("$f")
done < <(printf '%s\n' "${stale[@]}" | sort -u)

if [ "${#present[@]}" -eq 0 ]; then
  echo "nothing to remove"
  exit 0
fi

printf 'In /etc:\n'
printf '    %s\n' "${present[@]}"

if ! $apply; then
  printf '\nDry run. Apply with: %s --apply\n' "$0"
  exit 0
fi

sudo rm -rf -- "${present[@]}"
echo "removed ${#present[@]} entries"
