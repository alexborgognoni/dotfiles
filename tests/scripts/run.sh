#!/usr/bin/env bash
# Runs the script tests: tests/scripts/run.sh [pattern]
# Hermetic except test-cleanup-smoke.sh (a read-only dry run on this machine).
# Needs bash, coreutils, sed, awk, grep; shellcheck and python3+yaml when present.
set -u
cd "$(dirname "$0")" || exit 1
pattern="${1:-}"
failed=0
for t in test-*.sh; do
  case "$t" in *"$pattern"*) ;; *) continue ;; esac
  bash "$t" || failed=$((failed + 1))
done
if [ "$failed" -eq 0 ]; then echo "all test files passed"; else echo "$failed test file(s) failed"; fi
exit "$failed"
