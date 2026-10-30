#!/usr/bin/env bash
# origin_foreign: which packages come from outside Ubuntu's archive.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"
# shellcheck source=../../scripts/lib/common.sh
. "$repo/scripts/lib/common.sh"
# shellcheck source=stubs.sh
. "$(dirname "$0")/stubs.sh"

install_apt_cache_stub "$tmp"
cat > "$tmp/origins" <<'ORIGINS'
from-mirror ubuntu
from-security security
from-esm esm
from-ports ports
no-origin-given-defaults-to-ubuntu ubuntu
from-vendor vendor
from-docker docker
from-ppa ppa
from-deb local
spoof-suffix spoof1
spoof-subdomain spoof2
corporate-mirror mirror
ORIGINS

got="$(origin_foreign from-mirror from-security from-esm from-ports no-origin-given-defaults-to-ubuntu from-vendor from-docker from-ppa from-deb spoof-suffix spoof-subdomain corporate-mirror | sort | paste -sd,)"
assert_eq "$got" "corporate-mirror,from-deb,from-docker,from-ppa,from-vendor,spoof-subdomain,spoof-suffix" "vendor, PPA, local .deb, look-alike and mirror origins are foreign; Ubuntu hosts are not"

: > "$tmp/apt-cache-calls"
origin_foreign > /dev/null
assert_eq "$(wc -l < "$tmp/apt-cache-calls" | tr -d ' ')" "0" "no packages: apt-cache is not asked (it would list everything)"

finish
