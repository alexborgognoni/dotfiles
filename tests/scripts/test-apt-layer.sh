#!/usr/bin/env bash
# scripts/apt-layer.sh against a fake root and stubbed apt, dpkg, curl, usermod,
# chsh, getent and id: nothing on this machine is touched.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"

# --- a copy of the repository the script can run from, and the stubs ------------
work="$tmp/repo"
mkdir -p "$work/scripts" "$tmp/bin" "$tmp/state" "$tmp/root/etc" "$tmp/config"
cp -r "$repo/scripts/lib" "$repo/scripts/apt-layer.sh" "$work/scripts/"
cp -r "$repo/apt" "$work/apt"
printf 'ID=ubuntu\nVERSION_CODENAME=jammy\n' >"$tmp/root/etc/os-release"

stub() { # <name> <body>
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$tmp/bin/$1"
  chmod +x "$tmp/bin/$1"
}
stub dpkg-query 'pkg="${@: -1}"; line="$(grep "^$pkg " "$STUB_STATE/installed" 2>/dev/null | head -1)"; [ -n "$line" ] || exit 1; printf "%s" "${line#* }"'
stub apt-get 'echo "apt-get $*" >>"$STUB_STATE/log"
if [ "$1" = install ]; then
  for a in "${@:3}"; do
    case "$a" in -*) ;; *.deb) b="$(basename "$a" .deb)"; echo "$b install ok installed" >>"$STUB_STATE/installed" ;; *) echo "$a install ok installed" >>"$STUB_STATE/installed" ;; esac
  done
fi'
stub curl 'echo "curl $*" >>"$STUB_STATE/log"; while [ $# -gt 0 ]; do [ "$1" = -o ] && : >"$2"; shift; done'
stub usermod 'echo "usermod $*" >>"$STUB_STATE/log"'
stub chsh 'echo "chsh $*" >>"$STUB_STATE/log"'
stub getent 'case "$1" in
  group) for g in $STUB_GROUPS_EXIST; do [ "$g" = "$2" ] && exit 0; done; exit 1 ;;
  passwd) echo "$2:x:1000:1000::/home/$2:${STUB_SHELL:-/bin/bash}" ;;
esac'
stub id 'case "$1" in
  -u) echo "${STUB_UID:-0}" ;;
  -un) echo alice ;;
  -nG) echo "${STUB_GROUPS:-alice}" ;;
esac'

export STUB_STATE="$tmp/state" STUB_GROUPS_EXIST="docker libvirt"
reset() {
  rm -rf "$tmp/state" "$tmp/root/etc/apt" "$tmp/config/dotfiles"
  mkdir -p "$tmp/state"
  : >"$tmp/state/log"
  : >"$tmp/state/installed"
}
# run [args]: the script as root for alice; output in $out, exit status in $rc
run() {
  rc=0
  out="$(PATH="$tmp/bin:$PATH" SUDO_USER=alice APT_LAYER_ROOT="$tmp/root" XDG_CONFIG_HOME="$tmp/config" \
    "$work/scripts/apt-layer.sh" "$@" 2>&1)" || rc=$?
  out="$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')"
  log="$(cat "$tmp/state/log")"
}
calls() { grep -c "^$1" "$tmp/state/log" || true; }

# --- a fresh machine, applied -------------------------------------------------------
reset
run
assert_eq "$rc" "0" "fresh machine: exits cleanly"
assert_eq "$(cmp "$repo/apt/keys/docker.asc" "$tmp/root/etc/apt/keyrings/docker.asc" && echo same)" "same" "the Docker key is installed"
repo_line="$(cat "$tmp/root/etc/apt/sources.list.d/docker.list")"
assert_match "$repo_line" 'download.docker.com/linux/ubuntu jammy stable' "the Docker repository names the release (jammy)"
assert_nomatch "$repo_line" '@RELEASE@' "no placeholder is left in the repository line"
assert_match "$log" 'apt-get update' "apt is updated before installing"
assert_match "$log" 'apt-get install -y .*docker-ce' "the packages are installed (docker-ce)"
assert_match "$log" 'apt-get install -y .*qt6-wayland' "the packages are installed (qt6-wayland)"
assert_match "$log" 'curl .*go.microsoft.com/fwlink' "Edge is downloaded"
assert_match "$log" 'apt-get install -y .*microsoft-edge-stable.deb' "Edge is installed from the .deb"
assert_match "$log" 'usermod -aG docker alice' "the user joins docker"
assert_match "$log" 'usermod -aG libvirt alice' "the user joins libvirt"
assert_match "$log" 'chsh -s /usr/bin/zsh alice' "zsh becomes the login shell"

# --- the same machine again: nothing to do, nothing touched --------------------------
: >"$tmp/state/log"
STUB_GROUPS="alice docker libvirt" STUB_SHELL=/usr/bin/zsh run
assert_eq "$rc" "0" "second run: exits cleanly"
assert_match "$out" 'nothing to do' "second run: nothing to do"
assert_eq "$(wc -c <"$tmp/state/log" | tr -d ' ')" "0" "second run: no apt, curl, usermod or chsh call (no network)"

# --- --check: reports, exits 1, changes nothing -------------------------------------------
reset
run --check
assert_eq "$rc" "1" "--check on a fresh machine: exits 1 (changes pending)"
assert_match "$out" 'would: install [0-9]+ package' "--check lists the packages"
assert_match "$out" 'would: write the docker repository' "--check lists the repository"
assert_eq "$(wc -c <"$tmp/state/log" | tr -d ' ')" "0" "--check: no command with an effect ran"
assert_eq "$(ls "$tmp/root/etc/apt" 2>/dev/null | wc -l | tr -d ' ')" "0" "--check: no file written"
STUB_UID=1000 run --check
assert_eq "$rc" "1" "--check needs no root"
# a complete machine passes --check
reset
run
STUB_GROUPS="alice docker libvirt" STUB_SHELL=/usr/bin/zsh run --check
assert_eq "$rc" "0" "--check on an up-to-date machine: exits 0"

# --- an entry for one machine only -----------------------------------------------------------
: >"$tmp/state/log"
mkdir -p "$tmp/config/dotfiles/apt"
printf '# this machine only\nhtop\n' >"$tmp/config/dotfiles/apt/packages.list"
STUB_GROUPS="alice docker libvirt" STUB_SHELL=/usr/bin/zsh run
assert_match "$log" 'apt-get install -y htop$' "the per-user apt/packages.list (under .config/dotfiles) adds a package"
assert_nomatch "$log" 'docker-ce' "...and only that one is installed"
rm -rf "$tmp/config/dotfiles"

# --- a package on hold is installed ---------------------------------------------------------
reset
run
sed -i 's/^docker-buildx-plugin install ok installed/docker-buildx-plugin hold ok installed/' "$tmp/state/installed"
: >"$tmp/state/log"
STUB_GROUPS="alice docker libvirt" STUB_SHELL=/usr/bin/zsh run
assert_match "$out" 'nothing to do' "a package on hold counts as installed"

# --- a changed repository is rewritten --------------------------------------------------------
echo 'deb https://example.invalid/docker jammy stable' >"$tmp/root/etc/apt/sources.list.d/docker.list"
STUB_GROUPS="alice docker libvirt" STUB_SHELL=/usr/bin/zsh run
assert_match "$out" 'write the docker repository' "a repository that differs is rewritten"
assert_match "$(cat "$tmp/root/etc/apt/sources.list.d/docker.list")" 'download.docker.com' "...to the declared one"

# --- refusals ---------------------------------------------------------------------------------------
reset
STUB_UID=1000 run
assert_match "$out" 'sudo' "applying without root is refused"
assert_eq "$(wc -c <"$tmp/state/log" | tr -d ' ')" "0" "...before anything ran"
run --user root
assert_match "$out" 'not for root' "root's own groups and shell are never touched"

# --- the shipped data ---------------------------------------------------------------------------------
# tracked by git: a blanket *.asc rule in .gitignore once kept the key out of the repository
assert_eq "$(git -C "$repo" ls-files apt/keys/docker.asc)" "apt/keys/docker.asc" "the Docker key is tracked by git (not ignored)"
for list in "$repo"/apt/repos/*.list; do
  name="$(basename "$list" .list)"
  [ -f "$repo/apt/keys/$name.asc" ] && ok || fail "apt/keys/$name.asc is missing for apt/repos/$name.list"
  assert_match "$(cat "$list")" 'signed-by=/etc/apt/keyrings/'"$name"'\.asc' "$name: the repository points at its keyring"
done
packages="$(
  normalize_list() { sed -E 's/[[:space:]]*#.*$//; /^[[:space:]]*$/d' "$1"; }
  normalize_list "$repo/apt/packages.list"
)"
assert_eq "$(printf '%s\n' "$packages" | sort | uniq -d | paste -sd,)" "" "apt/packages.list has no duplicates"
assert_match "$(printf '%s\n' "$packages" | grep -c .)" '^[1-9]' "apt/packages.list declares packages"
while read -r package url; do
  assert_match "$url" '^https://' "vendor deb $package: an https URL"
done < <(sed -E 's/[[:space:]]*#.*$//; /^[[:space:]]*$/d' "$repo/apt/vendor-debs.list")
# the pinned Docker key is Docker's (official fingerprint)
if command -v gpg >/dev/null; then
  fpr="$(gpg --show-keys --with-colons "$repo/apt/keys/docker.asc" 2>/dev/null | awk -F: '/^fpr/ { print $10 }')"
  assert_match "$fpr" '9DC858229FC7DD38854AE2D88D81803C0EBFCD88' "apt/keys/docker.asc has Docker's official key fingerprint"
else
  echo "  skip: gpg is not available (Docker key fingerprint)"
fi

finish
