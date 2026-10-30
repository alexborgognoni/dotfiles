#!/usr/bin/env bash
# The repository itself: shell syntax, shellcheck, executable bits, Markdown
# links, no pointers to removed files, and that install only calls scripts
# that exist.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"

cd "$repo" || exit 1
shell_files="install $(ls scripts/*.sh scripts/lib/*.sh tests/scripts/*.sh tests/ubuntu-vm/*.sh)"

# --- syntax -----------------------------------------------------------------
for f in $shell_files; do
  bash -n "$f" 2>/dev/null && ok || fail "syntax error in $f"
done

# --- shellcheck (warnings and above): from PATH, else through Nix, else skipped
sc=()
if command -v shellcheck >/dev/null; then
  sc=(shellcheck)
elif command -v nix >/dev/null; then sc=(nix --extra-experimental-features "nix-command flakes" shell nixpkgs#shellcheck -c shellcheck); fi
if [ "${#sc[@]}" -gt 0 ]; then
  # shellcheck disable=SC2086
  out="$("${sc[@]}" --severity=warning $shell_files 2>&1)" && ok || fail "shellcheck: $(printf '%s' "$out" | grep -E '^In |SC[0-9]+' | head -6 | paste -sd' ')"
else
  echo "  skip: shellcheck is not available"
fi

# --- the shared library is sourced before anything uses it ---------------------
# (shellcheck cannot see this: it only knows the variable is set somewhere)
for f in scripts/bootstrap-nix.sh scripts/snapshot-system.sh scripts/cleanup-ubuntu.sh; do
  src="$(grep -nE '^\. .*lib/common\.sh' "$f" | head -1 | cut -d: -f1)"
  if [ -z "$src" ]; then
    fail "$f does not source lib/common.sh"
    continue
  fi
  first="$(awk '/^[[:space:]]*#/ { next } /\$dotfiles|\$\{dotfiles|(^|[^A-Za-z_])(log|die|item|warn|list_regex|list_entries|origin_foreign|apt_plan) / { print NR; exit }' "$f")"
  if [ -z "$first" ] || [ "$src" -lt "$first" ]; then ok; else fail "$f uses the shared library (line $first) before sourcing it (line $src)"; fi
done

# --- the scripts people run are executable ----------------------------------
for f in install scripts/bootstrap-nix.sh scripts/snapshot-system.sh scripts/cleanup-ubuntu.sh tests/scripts/run.sh tests/ubuntu-vm/create.sh tests/ubuntu-vm/run.sh tests/ubuntu-vm/verify.sh; do
  [ -x "$f" ] && ok || fail "$f is not executable"
done

# --- every relative Markdown link resolves -----------------------------------
for md in README.md scripts/README.md nix/README.md docs/*.md; do
  dir="$(dirname "$md")"
  while IFS= read -r target; do
    target="${target%%#*}"
    [ -n "$target" ] || continue
    [ -e "$dir/$target" ] && ok || fail "$md links to $target, which does not exist"
  done < <(grep -oE '\]\([^)]+\)' "$md" | sed -E 's/^\]\(//; s/\)$//' | grep -vE '^(https?:|mailto:|#)')
done

# --- nothing points at what was removed ---------------------------------------
legacy='scripts/(install-legacy|migrate-to-home-manager|rollback-to-chezmoi|dump-packages|dump-gnome-settings|test-docker|test-profile-switching|test-ubuntu-hm)|ansible/|chezmoi/|docs/(DESIGN|PROFILES|TESTING|SECRETS|UBUNTU-MIGRATION)'
hits="$(grep -rInE "$legacy" --exclude-dir=.git --exclude-dir=result . | grep -vE '^\./docs/NIX-PLAN\.md:|^\./tests/scripts/test-repo\.sh:' || true)"
assert_eq "$hits" "" "no reference to a removed script, role or doc"

# --- install calls only scripts that exist -----------------------------------
for s in $(grep -oE '\$dir/scripts/[A-Za-z0-9._/-]+' install | sed 's|\$dir/||' | sort -u); do
  [ -f "$s" ] && ok || fail "install calls $s, which does not exist"
done

finish
