#!/usr/bin/env bash
# The repository-wide format check and linters (nix run path:nix#lint):
# nixfmt, shfmt, stylua, statix, deadnix, shellcheck, selene. Needs Nix.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"

if ! command -v nix >/dev/null; then
  echo "  skip: nix is not available"
  finish
  exit 0
fi

rc=0
out="$(cd "$repo" && nix --extra-experimental-features "nix-command flakes" run path:nix#lint 2>&1 | sed 's/\x1b\[[0-9;]*m//g')" || rc=$?
assert_eq "$rc" "0" "nix run path:nix#lint passes (run nix fmt to fix formatting)"
[ "$rc" -eq 0 ] || printf '%s\n' "$out" | grep -v '^copying\|^this \|^  /nix' | head -40
for step in format statix deadnix shellcheck selene; do
  assert_match "$out" "==> $step" "lint step ran: $step"
done

finish
