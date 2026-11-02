#!/usr/bin/env bash
# The workflows that must keep working, run for real on this machine: install
# and load a native addon, make a virtualenv with wheels, build a Rust, Go, C or
# Java program, fetch over HTTPS through the corporate proxy, run a container.
# Run it after a switch and after a nixpkgs update (`nix flake update`).
#
# The tests in nix/checks prove the mechanism in a sandbox; this proves the
# workflow, which needs the network, the GPU and the real environment, so it
# cannot run in a sandbox or in CI. Every regression found while building the
# runtimes (Java behind the proxy, uv picking a Python too new for a tool, torch
# without the GPU) would have shown here first.
#
#   scripts/doctor.sh                  everything that applies to this machine
#   scripts/doctor.sh --offline        without the checks that need the network
#   scripts/doctor.sh --only python    the checks whose name contains the text
#   scripts/doctor.sh --list           what would run, nothing is run
#
# Checks: scripts/doctor.d/*.sh (shipped, generic). A machine adds its own in
# ~/.config/dotfiles/doctor.d/*.sh (a project of this laptop, nothing of it is in
# this repository). Each file calls
#
#   check "<name>" "<tags>" '<command>'
#
# tags: net (needs the network, skipped by --offline), gpu (skipped without an
# NVIDIA GPU). The command runs in a new shell with the environment of a fresh
# login (Home Manager's once-per-session guards are cleared, so a session that
# predates the last switch still sees its variables), in an empty directory that
# is removed afterwards, with a time limit (DOCTOR_TIMEOUT seconds, default 900).
# $DOCTOR_PROBES is scripts/doctor.d/probes, for files a command needs.
set -uo pipefail

# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

offline=false
list=false
only=""
while [ $# -gt 0 ]; do
  case "$1" in
    --offline) offline=true ;;
    --list) list=true ;;
    --only)
      shift
      only="${1:?--only needs a text}"
      ;;
    *) die "usage: doctor.sh [--offline] [--only TEXT] [--list]" ;;
  esac
  shift
done

timeout_seconds="${DOCTOR_TIMEOUT:-900}"
DOCTOR_PROBES="$dotfiles/scripts/doctor.d/probes"
export DOCTOR_PROBES
if command -v zsh >/dev/null; then shell=(zsh -c); else shell=(bash -c); fi

passed=0
failed=0
skipped=0

has_gpu() { command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1; }
tagged() { [[ " $1 " == *" $2 "* ]]; }

# check "<name>" "<tags>" '<command>'
check() {
  local name="$1" tags="$2" command="$3" dir output status=0
  [ -z "$only" ] || [[ "$name" == *"$only"* ]] || return 0
  if $list; then
    printf '  %-8s %s\n' "${tags:--}" "$name"
    return 0
  fi
  if tagged "$tags" net && $offline; then
    printf '  \033[33mskip\033[0m %s (offline)\n' "$name"
    skipped=$((skipped + 1))
    return 0
  fi
  if tagged "$tags" gpu && ! has_gpu; then
    printf '  \033[33mskip\033[0m %s (no NVIDIA GPU)\n' "$name"
    skipped=$((skipped + 1))
    return 0
  fi
  dir="$(mktemp -d)"
  output="$(cd "$dir" && env -u __HM_SESS_VARS_SOURCED -u __HM_ZSH_SESS_VARS_SOURCED -u LD_LIBRARY_PATH \
    timeout "$timeout_seconds" "${shell[@]}" "$command" 2>&1)" || status=$?
  chmod -R u+w "$dir" 2>/dev/null
  rm -rf "$dir"
  if [ "$status" -eq 0 ]; then
    printf '  \033[32mok\033[0m   %s\n' "$name"
    passed=$((passed + 1))
  else
    [ "$status" -ne 124 ] || output="timed out after ${timeout_seconds}s"$'\n'"$output"
    printf '  \033[31mFAIL\033[0m %s\n' "$name"
    printf '%s\n' "$output" | tail -6 | sed 's/^/         /'
    failed=$((failed + 1))
  fi
}

for file in "$dotfiles"/scripts/doctor.d/*.sh "${XDG_CONFIG_HOME:-$HOME/.config}"/dotfiles/doctor.d/*.sh; do
  [ -r "$file" ] || continue
  # shellcheck disable=SC1090
  . "$file"
done

$list && exit 0
printf '\n%d passed, %d failed, %d skipped\n' "$passed" "$failed" "$skipped"
[ "$failed" -eq 0 ]
