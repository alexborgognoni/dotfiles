#!/usr/bin/env bash
# scripts/doctor.sh (the engine, with fake checks): pass, fail and skip, the
# filters, the time limit, the clean environment and directory of every check,
# and the checks of one machine. The shipped checks (doctor.d/runtimes.sh) run
# real workflows and are not part of this test.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"

work="$tmp/repo"
mkdir -p "$work/scripts/doctor.d/probes" "$tmp/config/dotfiles/doctor.d" "$tmp/bin" "$tmp/home"
# no GPU unless a test puts one there (this machine may have one)
printf '#!/bin/sh\nexit 1\n' >"$tmp/bin/nvidia-smi"
chmod +x "$tmp/bin/nvidia-smi"
cp -r "$repo/scripts/lib" "$repo/scripts/doctor.sh" "$work/scripts/"

# a fake set of checks next to the engine
cat >"$work/scripts/doctor.d/fake.sh" <<'EOF'
check "passes" "" 'true'
check "needs the network" "net" 'touch "$DOCTOR_TEST_MARK/net-ran"'
check "needs a GPU" "gpu" 'touch "$DOCTOR_TEST_MARK/gpu-ran"'
check "runs in an empty directory" "" '[ -z "$(ls -A)" ] && touch leftover'
check "runs in an empty directory again" "" '[ -z "$(ls -A)" ]'
check "has a probes directory" "" '[ -d "$DOCTOR_PROBES" ]'
check "sees the environment of a fresh login" "" '[ -z "${__HM_SESS_VARS_SOURCED:-}${__HM_ZSH_SESS_VARS_SOURCED:-}${LD_LIBRARY_PATH:-}" ]'
EOF

mkdir -p "$tmp/mark"
export DOCTOR_TEST_MARK="$tmp/mark"
# run [args]: the engine; output in $out (colours removed), exit status in $rc
run() {
  rc=0
  out="$(env -u ZDOTDIR HOME="$tmp/home" PATH="$tmp/bin:$PATH" XDG_CONFIG_HOME="$tmp/config" "$work/scripts/doctor.sh" "$@" 2>&1)" || rc=$?
  out="$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')"
}

# --- everything that applies passes, a missing GPU and --offline skip --------------------
run
assert_eq "$rc" "0" "all pass: exit 0"
assert_match "$out" '5 passed, 0 failed, 2 skipped|6 passed, 0 failed, 1 skipped' "the summary counts passes and skips"
assert_match "$out" 'skip needs a GPU \(no NVIDIA GPU\)' "a GPU check is skipped without a GPU"
assert_eq "$(ls "$tmp/mark")" "net-ran" "the network check ran, the GPU check did not"

# --- a GPU is there: the GPU check runs ------------------------------------------------------
printf '#!/bin/sh\necho "GPU 0: fake"\n' >"$tmp/bin/nvidia-smi"
chmod +x "$tmp/bin/nvidia-smi"
rm -f "$tmp/mark/"*
run
assert_eq "$(ls "$tmp/mark" | sort | paste -sd,)" "gpu-ran,net-ran" "with nvidia-smi the GPU check runs"
assert_match "$out" '7 passed, 0 failed, 0 skipped' "everything ran"
printf '#!/bin/sh\nexit 1\n' >"$tmp/bin/nvidia-smi"

# --- --offline skips the network checks -------------------------------------------------------
rm -f "$tmp/mark/"*
run --offline
assert_match "$out" 'skip needs the network \(offline\)' "--offline skips a network check"
assert_eq "$(ls "$tmp/mark")" "" "...and does not run it"

# --- every check gets an empty directory, removed afterwards -------------------------------------------
run --only "empty directory"
assert_match "$out" '2 passed, 0 failed' "a check leaves nothing for the next one"

# --- --only and --list -------------------------------------------------------------------------------------
rm -f "$tmp/mark/"*
run --only "network"
assert_match "$out" '1 passed' "--only runs the matching checks"
assert_nomatch "$out" 'passes|GPU' "...and no other"
rm -f "$tmp/mark/"*
run --list
assert_eq "$rc" "0" "--list: exit 0"
assert_match "$out" 'net +needs the network' "--list shows the tags and names"
assert_match "$out" '- +passes' "--list shows an untagged check with a dash"
assert_eq "$(ls "$tmp/mark")" "" "--list runs nothing"
assert_nomatch "$out" 'passed' "--list prints no summary"

# --- a failing check: shown, the others still run, exit 1 ------------------------------------------------------
cat >"$work/scripts/doctor.d/broken.sh" <<'EOF'
check "fails loudly" "" 'echo "the reason it failed" >&2; exit 3'
EOF
run
assert_eq "$rc" "1" "a failing check: exit 1"
assert_match "$out" 'FAIL fails loudly' "the failing check is named"
assert_match "$out" 'the reason it failed' "...with the end of its output"
assert_match "$out" '[1-9] passed, 1 failed' "the other checks still ran"
rm -f "$work/scripts/doctor.d/broken.sh"

# --- the time limit ---------------------------------------------------------------------------------------------------
cat >"$work/scripts/doctor.d/slow.sh" <<'EOF'
check "never finishes" "" 'sleep 30'
EOF
rc=0
out="$(env -u ZDOTDIR HOME="$tmp/home" DOCTOR_TIMEOUT=1 PATH="$tmp/bin:$PATH" XDG_CONFIG_HOME="$tmp/config" "$work/scripts/doctor.sh" --only "never" 2>&1)" || rc=$?
out="$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')"
assert_eq "$rc" "1" "a check over the time limit fails"
assert_match "$out" 'timed out after 1s' "...and says so"
rm -f "$work/scripts/doctor.d/slow.sh"

# --- the environment of a fresh login ---------------------------------------------------------------------------------------
rc=0
out="$(env -u ZDOTDIR HOME="$tmp/home" __HM_SESS_VARS_SOURCED=1 __HM_ZSH_SESS_VARS_SOURCED=1 LD_LIBRARY_PATH=/somewhere PATH="$tmp/bin:$PATH" \
  XDG_CONFIG_HOME="$tmp/config" "$work/scripts/doctor.sh" --only "fresh login" 2>&1)" || rc=$?
assert_eq "$rc" "0" "a session that predates a switch (guards set) still gets a fresh environment"

# --- the checks of one machine -----------------------------------------------------------------------------------------------
cat >"$tmp/config/dotfiles/doctor.d/project.sh" <<'EOF'
check "a project of this machine" "" 'true'
EOF
run --only "project"
assert_match "$out" 'ok +a project of this machine' "a check in ~/.config/dotfiles/doctor.d runs"
assert_match "$out" '1 passed' "...and is counted"
rm -f "$tmp/config/dotfiles/doctor.d/project.sh"

# --- arguments ---------------------------------------------------------------------------------------------------------------------
run --nonsense
assert_eq "$rc" "1" "an unknown argument is refused"
assert_match "$out" 'usage' "...with the usage"

# --- the shipped data ---------------------------------------------------------------------------------------------------------------
assert_eq "$(bash -c "bash -n '$repo/scripts/doctor.d/runtimes.sh' && echo valid")" "valid" "the shipped checks parse"
shipped="$(grep -c '^check ' "$repo/scripts/doctor.d/runtimes.sh")"
assert_match "$shipped" '^[1-9][0-9]*$' "the shipped checks exist ($shipped)"
names="$(grep -h -o '^check "[^"]*"' "$repo"/scripts/doctor.d/*.sh | sort | uniq -d | paste -sd,)"
assert_eq "$names" "" "no shipped check name is used twice"
assert_eq "$(test -f "$repo/scripts/doctor.d/probes/Https.java" && echo yes)" "yes" "the probes the checks use exist"

finish
