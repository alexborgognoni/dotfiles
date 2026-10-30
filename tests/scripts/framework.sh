# shellcheck shell=bash
# Minimal test helpers, no dependencies. A test file sources this, runs its
# assertions and ends with `finish`.
# shellcheck disable=SC2034 # used by the test files that source this
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
passed=0
failed=0
suite="$(basename "${0%.sh}")"

ok() { passed=$((passed + 1)); }
fail() {
  failed=$((failed + 1))
  printf '  FAIL [%s] %s\n' "$suite" "$*"
}

# assert_eq <actual> <expected> <what>
assert_eq() { if [ "$1" = "$2" ]; then ok; else fail "$3: expected [$2], got [$1]"; fi; }
# assert_match <text> <ERE> <what>
assert_match() { if printf '%s' "$1" | grep -qE -e "$2"; then ok; else fail "$3: [$1] does not match $2"; fi; }
# assert_nomatch <text> <ERE> <what>
assert_nomatch() { if printf '%s' "$1" | grep -qE -e "$2"; then fail "$3: [$1] matches $2"; else ok; fi; }

# a throw-away directory, removed when the test ends
# shellcheck disable=SC2034 # used by the test files
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

finish() {
  printf '%-22s %d passed, %d failed\n' "$suite" "$passed" "$failed"
  [ "$failed" -eq 0 ]
}
