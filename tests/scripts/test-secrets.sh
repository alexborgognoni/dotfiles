#!/usr/bin/env bash
# Secrets hygiene: the sops files are really encrypted, only the intended
# recipients can decrypt them, and no private key or token is in git.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"

cd "$repo" || exit 1
sops_config=nix/.sops.yaml

# --- the keys .sops.yaml knows ------------------------------------------------
admin="$(sed -nE 's/^[[:space:]]*-[[:space:]]*&admin[[:space:]]+(age1[a-z0-9]+).*/\1/p' "$sops_config")"
known="$(sed -nE 's/^[[:space:]]*-[[:space:]]*&[a-z0-9_-]+[[:space:]]+(age1[a-z0-9]+).*/\1/p' "$sops_config" | sort)"
assert_match "$admin" '^age1[a-z0-9]{50,}$' "an admin key is declared in $sops_config"
assert_match "$known" 'age1' "recipient keys are declared in $sops_config"

# --- every secrets file -------------------------------------------------------
files="$(git ls-files 'nix/secrets/*.yaml')"
assert_match "$files" 'secrets/' "there are sops files"
for f in $files; do
  name="$(basename "$f" .yaml)"

  # encrypted: every value before the `sops:` block is ENC[...], and the block has a MAC
  plain="$(awk '/^sops:/ { exit } /^[A-Za-z_][^:]*:[[:space:]]*[^[:space:]]/ { v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); if (v !~ /^ENC\[AES256_GCM,/) print }' "$f")"
  assert_eq "$plain" "" "$name: every value is encrypted"
  assert_match "$(grep -c '^sops:' "$f")" '^1$' "$name: has the sops metadata"
  assert_match "$(grep -cE '^[[:space:]]+mac: ENC\[' "$f")" '^[1-9]' "$name: is integrity-protected (mac)"

  # who can decrypt it: only keys that .sops.yaml declares
  recipients="$(grep -oE 'recipient: age1[a-z0-9]+' "$f" | sed 's/recipient: //' | sort -u)"
  assert_match "$recipients" 'age1' "$name: has recipients"
  stray="$(comm -23 <(printf '%s\n' "$recipients") <(printf '%s\n' "$known"))"
  assert_eq "$stray" "" "$name: no recipient that .sops.yaml does not declare"

  # covered by a creation rule, so `sops` and updatekeys know its recipients
  assert_match "$(grep -cE "path_regex:.*${name}\\\\\\.yaml" "$sops_config")" '^[1-9]' "$name: has a creation rule in .sops.yaml"
done

# the work keys are for the admin key (the corporate laptop) only
work_recipients="$(grep -oE 'recipient: age1[a-z0-9]+' nix/secrets/work.yaml | sed 's/recipient: //' | sort -u)"
assert_eq "$work_recipients" "$admin" "work.yaml can be decrypted by the admin key only"

# --- nothing secret in git ------------------------------------------------------
# (private key blocks, an age secret key, common token shapes; this file is excluded
# because it names them)
patterns=(
  '-----BEGIN ([A-Z]+ )?PRIVATE KEY( BLOCK)?-----'
  'AGE-SECRET-KEY-1[QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L]{58}'
  'gh[pousr]_[A-Za-z0-9]{36,}'
  'github_pat_[A-Za-z0-9_]{50,}'
  'AKIA[0-9A-Z]{16}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
)
# a sample of each shape, so a broken pattern cannot pass by matching nothing
samples=(
  '-----BEGIN OPENSSH PRIVATE KEY-----'
  'AGE-SECRET-KEY-1QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7LQPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L'
  'ghp_0123456789abcdefghijklmnopqrstuvwxyz'
  'github_pat_0123456789abcdefghijklmnopqrstuvwxyz0123456789abcdef'
  'AKIAABCDEFGHIJKLMNOP'
  'xoxb-0123456789-abc'
)
for i in "${!patterns[@]}"; do
  assert_match "${samples[$i]}" "${patterns[$i]}" "pattern $i matches its sample"
  hits="$(git grep -I -lE -e "${patterns[$i]}" -- . ':(exclude)tests/scripts/test-secrets.sh')" && rc=0 || rc=$?
  # git grep: 0 = found, 1 = nothing found, anything else = an error
  assert_eq "$rc" "1" "no tracked file matches ${patterns[$i]}${hits:+ (in: $hits)}"
done

# the key file and key-like files are ignored
for ignored in nix/secrets/x.key keys.pem id_rsa; do
  assert_match "$(git check-ignore "$ignored" || echo "NOT IGNORED $ignored")" "$ignored" "gitignore covers $ignored"
done

finish
