#!/usr/bin/env bash
# apt_plan: what the cleanup removes, keeps because of its origin, or never
# considers. Precedence: drop list > protect list > vendor origin > the rest.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"
# shellcheck source=../../scripts/lib/common.sh
. "$repo/scripts/lib/common.sh"
# shellcheck source=stubs.sh
. "$(dirname "$0")/stubs.sh"

install_apt_cache_stub "$tmp"
cat >"$tmp/origins" <<'ORIGINS'
nvidia-driver-595-open vendor
acme-tool vendor
acme-agent vendor
postgresql-14 vendor
cuda-toolkit-12 vendor
microsoft-edge-stable vendor
docker-ce docker
some-ppa-tool ppa
local-deb local
ORIGINS
export XDG_CONFIG_HOME="$tmp/config" # no per-user lists yet

names() { printf '%s\n' "$@" | sort -u; }
removes() { awk '$1 == "remove" { print $2 }' <<<"$1" | paste -sd,; }
vendors() { awk '$1 == "vendor" { print $2 }' <<<"$1" | paste -sd,; }

# installed by hand
names old-tool declared-tool base-pkg nvidia-driver-595-open acme-tool acme-agent postgresql-14 \
  cuda-toolkit-12 microsoft-edge-stable docker-ce some-ppa-tool local-deb >"$tmp/manual"
names base-pkg >"$tmp/initial"                 # came with Ubuntu
names declared-tool docker-ce >"$tmp/declared" # ansible/ubuntu.yml
# everything installed, including parts that came in as dependencies
{
  cat "$tmp/manual"
  names postgresql-common zsh
} | sort -u >"$tmp/installed"

plan="$(apt_plan "$tmp/manual" "$tmp/initial" "$tmp/declared" "$tmp/installed")"
assert_eq "$(removes "$plan")" "cuda-toolkit-12,old-tool,postgresql-14,postgresql-common" \
  "removed: an Ubuntu hand install, and the dropped families (from vendors too, auto-installed parts too)"
assert_eq "$(vendors "$plan")" "acme-agent,acme-tool,local-deb,some-ppa-tool" \
  "kept for their origin: vendor repository, PPA, local .deb"
# never listed at all: declared, in the original install, protected by name
for p in declared-tool docker-ce base-pkg nvidia-driver-595-open microsoft-edge-stable; do
  assert_nomatch "$plan" "(^|[[:space:]])$p\$" "$p is neither removed nor reported"
done

# a coworker protects their agent and drops a vendor tool, outside the repo
mkdir -p "$tmp/config/dotfiles/cleanup.d"
printf 'acme-agent\n' >"$tmp/config/dotfiles/cleanup.d/protect-packages.list"
printf 'acme-tool\n' >"$tmp/config/dotfiles/cleanup.d/drop-packages.list"
plan="$(apt_plan "$tmp/manual" "$tmp/initial" "$tmp/declared" "$tmp/installed")"
assert_eq "$(removes "$plan")" "acme-tool,cuda-toolkit-12,old-tool,postgresql-14,postgresql-common" \
  "the per-user drop list removes a vendor package"
assert_eq "$(vendors "$plan")" "local-deb,some-ppa-tool" \
  "the per-user protect list takes acme-agent out of the report; the dropped tool leaves it too"
assert_nomatch "$plan" "acme-agent" "a protected package is not listed at all"
rm -rf "$tmp/config"

# nothing installed by hand: only dropped families remain, and apt-cache is not
# asked about "all packages"
: >"$tmp/manual"
: >"$tmp/apt-cache-calls"
plan="$(apt_plan "$tmp/manual" "$tmp/initial" "$tmp/declared" "$tmp/installed")"
assert_eq "$(removes "$plan")" "cuda-toolkit-12,postgresql-14,postgresql-common" "only the dropped families (still installed) go when nothing was installed by hand"
assert_eq "$(vendors "$plan")" "" "no vendor packages reported"
assert_eq "$(wc -l <"$tmp/apt-cache-calls" | tr -d ' ')" "0" "apt-cache is not called without packages"

finish
