#!/usr/bin/env bash
# The lists in scripts/cleanup.d: valid, consistent, and unable to name
# anything dangerous.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"
# shellcheck source=../../scripts/lib/common.sh
. "$repo/scripts/lib/common.sh"

export XDG_CONFIG_HOME="$tmp/none" # only the shipped lists
lists="protect-packages.list drop-packages.list keep-snaps.list home-leftovers.list system-leftovers.list"

for l in $lists; do
  [ -r "$repo/scripts/cleanup.d/$l" ] && ok || fail "$l is missing"
  entries="$(list_entries "$l")"
  assert_eq "$(printf '%s\n' "$entries" | sort | uniq -d | paste -sd,)" "" "$l has no duplicate entries"
  assert_eq "$(printf '%s\n' "$entries" | grep -c '[[:space:]]' || true)" "0" "$l: no entry contains whitespace"
  rc=0
  echo x | grep -E "$(list_regex "$l")" >/dev/null 2>&1 || rc=$?
  [ "$rc" -le 1 ] && ok || fail "$l does not compile to a valid regex"
done

# the protect list covers what must never go
protect="$(list_regex protect-packages.list)"
for p in linux-image-generic linux-modules-nvidia-595-open-generic nvidia-driver-595-open libnvidia-compute-595 \
  firmware-sof-signed oem-sutton-balin-meta ubuntu-desktop zscaler-client falcon-sensor intune-portal \
  microsoft-edge-stable packages-microsoft-prod icaclient ud-agent cisco-secure-client; do
  assert_match "$p" "$protect" "protected: $p"
done
for p in postgresql-14 vim google-chrome-stable; do
  assert_nomatch "$p" "$protect" "not protected by name: $p"
done

# the drop list and the apt packages Ansible declares do not contradict
if python3 -c "import yaml" 2>/dev/null; then
  declared="$(python3 -c "
import yaml
v = yaml.safe_load(open('$repo/ansible/ubuntu.yml'))[0]['vars']
print('\n'.join(v['apt_packages'] + list(v.get('vendor_debs', {}))))")"
  drop="$(list_regex drop-packages.list)"
  clash="$(printf '%s\n' "$declared" | grep -E "$drop" | paste -sd, || true)"
  assert_eq "$clash" "" "no package declared in ansible/ubuntu.yml is in the drop list"
  # ...and the declared packages are not the ones the protect list would hide twice
  assert_match "$(printf '%s\n' "$declared" | wc -l | tr -d ' ')" '^[1-9]' "ansible/ubuntu.yml declares packages"
else
  echo "  skip: python3 yaml not available (ansible/ubuntu.yml consistency)"
fi

# snaps
snaps="$(list_regex keep-snaps.list)"
for s in snapd core22 core24 bare snap-store gnome-42-2204 gtk-common-themes mesa-2404 cups; do assert_match "$s" "$snaps" "snap kept: $s"; done
for s in firefox chromium teams-for-linux code; do assert_nomatch "$s" "$snaps" "snap removed: $s"; done

# the home list: relative, inside $HOME, never a whole personal directory
# entries contain "*": read them as lines, never let the shell expand them
while IFS= read -r e; do
  assert_nomatch "$e" '^(/|~|\.\./|\./)|(^|/)\.\.(/|$)' "home entry is relative and inside HOME: $e"
done < <(list_entries home-leftovers.list)
for danger in . .config .local .local/share .cache .ssh .gnupg .mozilla .config/google-chrome .config/sops .config/nvim Documents Downloads personal dotfiles; do
  assert_nomatch "$(list_entries home-leftovers.list | grep -Fx -- "$danger" || true)" '.' "home list must not contain $danger"
done

# the system list: absolute, only /usr/local and /opt, nothing broad
while IFS= read -r e; do
  assert_match "$e" '^/(usr/local|opt)/.+' "system entry is under /usr/local or /opt: $e"
  assert_nomatch "$e" '^/(usr/local|opt)/\*?$|\.\.' "system entry is specific, not a whole directory: $e"
done < <(list_entries system-leftovers.list)

finish
