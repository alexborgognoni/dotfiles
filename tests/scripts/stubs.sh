# shellcheck shell=bash
# install_apt_cache_stub <dir>: puts a fake `apt-cache policy` first on PATH.
# It reads "<package> <origin>" lines from $ORIGINS (default <dir>/origins) and
# prints the same layout as the real command; unknown packages are Ubuntu's.
install_apt_cache_stub() {
  mkdir -p "$1/bin"
  export ORIGINS="$1/origins"
  export CALLLOG="$1/apt-cache-calls"
  cat >"$1/bin/apt-cache" <<'STUB'
#!/usr/bin/env bash
[ "$1" = policy ] || exit 1
shift
if [ "$#" -eq 0 ]; then echo "called without packages" >> "$CALLLOG"; exit 0; fi
for p in "$@"; do
  origin="$(awk -v p="$p" '$1 == p { print $2 }' "$ORIGINS")"
  case "${origin:-ubuntu}" in
    ubuntu)  url="http://de.archive.ubuntu.com/ubuntu jammy-updates/main amd64 Packages" ;;
    security) url="http://security.ubuntu.com/ubuntu jammy-security/main amd64 Packages" ;;
    esm)     url="https://esm.ubuntu.com/apps/ubuntu jammy-apps-security/main amd64 Packages" ;;
    ports)   url="http://ports.ubuntu.com/ubuntu-ports jammy/main arm64 Packages" ;;
    vendor)  url="https://packages.microsoft.com/repos/edge stable/main amd64 Packages" ;;
    docker)  url="https://download.docker.com/linux/ubuntu jammy/stable amd64 Packages" ;;
    ppa)     url="https://ppa.launchpadcontent.net/someone/tools/ubuntu jammy/main amd64 Packages" ;;
    spoof1)  url="http://notubuntu.com/ubuntu jammy/main amd64 Packages" ;;
    spoof2)  url="http://ubuntu.com.evil.example/ubuntu jammy/main amd64 Packages" ;;
    mirror)  url="https://artifactory.corp.example/ubuntu-remote jammy/main amd64 Packages" ;;
    local)   url="" ;;
  esac
  printf '%s:\n  Installed: 1.0\n  Candidate: 1.0\n  Version table:\n *** 1.0 500\n' "$p"
  [ -z "$url" ] || printf '        500 %s\n' "$url"
  printf '        100 /var/lib/dpkg/status\n'
done
STUB
  chmod +x "$1/bin/apt-cache"
  PATH="$1/bin:$PATH"
}
