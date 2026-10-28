#!/usr/bin/env bash
# Prove the Home Manager setup for the Ubuntu work laptop in a Ubuntu 22.04
# container: reproduce today's chezmoi state, migrate, verify, roll back.
# Nothing on the host is changed. /nix is kept in a Docker volume between
# runs (docker volume rm ubuntu-hm-nix to start from scratch).
#
# Usage: scripts/test-ubuntu-hm.sh          (needs Docker and the sops admin key)
set -euo pipefail

dotfiles="$(cd "$(dirname "$0")/.." && pwd)"
image="dotfiles-ubuntu-hm"
agekey="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

[ -r "$agekey" ] || { echo "missing sops admin key $agekey" >&2; exit 1; }
if [ -n "$(git -C "$dotfiles" status --porcelain --untracked-files=normal -- nix scripts tests)" ]; then
  echo "note: flakes only see files tracked by git; run 'git add' for new files" >&2
fi

ctx="$(mktemp -d)"
trap 'rm -rf "$ctx"' EXIT
mkdir -p "$ctx/ca"
# Corporate root CAs installed on this machine (none: an empty directory)
cp /usr/local/share/ca-certificates/*.crt "$ctx/ca/" 2>/dev/null || true
cp "$dotfiles/tests/ubuntu-hm/Dockerfile" "$ctx/"

# Host networking: traffic leaves through the host's own network stack, which
# works behind VPNs/Zscaler where Docker's bridge NAT does not.
docker build --network host -t "$image" "$ctx"

# Capped: evaluating the laptop configuration peaks around 13 GB, plus
# source builds (patched Noctalia); without limits this can exhaust the
# host's memory, so memory and build parallelism are bounded. Don't run it
# next to the test VMs.
docker run --rm --network host --memory "${TEST_MEMORY:-24g}" --memory-swap "${TEST_MEMORY:-24g}" \
  -e NIX_CONFIG=$'cores = 4\nmax-jobs = 2' \
  -v ubuntu-hm-nix:/nix \
  -v "$dotfiles:/home/Alex/dotfiles:ro" \
  -v "$agekey:/run/agekey:ro" \
  "$image" bash /home/Alex/dotfiles/tests/ubuntu-hm/run-tests.sh
