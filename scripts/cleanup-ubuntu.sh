#!/usr/bin/env bash
# After the migration: remove everything installed outside Nix that Nix now
# provides, so the machine is "fresh Ubuntu + Nix". What stays is declared:
#   - packages of the original Ubuntu installation (/var/log/installer)
#   - ansible/ubuntu.yml (root daemons and the login shell)
#   - scripts/cleanup.d/protect-packages.list (corporate software, drivers,
#     system parts), and anything installed from outside Ubuntu's archive
# Everything removed is in the snapshot (scripts/snapshot-system.sh), which
# must exist first.
#
#   scripts/cleanup-ubuntu.sh            dry run: shows what would be removed
#   scripts/cleanup-ubuntu.sh --apply    removes it (asks once, needs sudo)
#   scripts/cleanup-ubuntu.sh --apply --yes   without asking
set -euo pipefail

apply=false
assume_yes=false
for arg in "$@"; do
  case "$arg" in
    --apply) apply=true ;;
    --yes) assume_yes=true ;;
  esac
done
. "$(dirname "$0")/lib/common.sh"

# What stays and what goes is data, in scripts/cleanup.d/*.list (see
# scripts/README.md); ~/.config/dotfiles/cleanup.d/ adds machine-specific entries.
# Order of precedence for apt packages: drop list, then protect list, then
# "installed from outside Ubuntu's archive" (kept), then default: removed.
protect="$(list_regex protect-packages.list)"
drop="$(list_regex drop-packages.list)"
snap_keep="$(list_regex keep-snaps.list)"

if ! ls "$HOME"/Backups/system-snapshot-*.tar.zst.age >/dev/null 2>&1; then
  $apply && die "no snapshot in ~/Backups; run scripts/snapshot-system.sh first"
  echo "(no snapshot yet: required before --apply)"
fi

# --- 1. apt ------------------------------------------------------------------
[ -s /var/log/installer/initial-status.gz ] \
  || die "no /var/log/installer/initial-status.gz: cannot tell which packages came with Ubuntu"
initial="$(zcat /var/log/installer/initial-status.gz | awk '/^Package:/{print $2}' | sort -u)"
declared="$(python3 -c "
import yaml,sys
play=yaml.safe_load(open('$dotfiles/ansible/ubuntu.yml'))[0]['vars']
print('\n'.join(play['apt_packages'] + list(play.get('vendor_debs',{}))))" | sort -u)"
apt_candidates="$(apt-mark showmanual | sort -u \
  | comm -23 - <(printf '%s\n' "$initial") \
  | comm -23 - <(printf '%s\n' "$declared") \
  | grep -vE "$protect" || true)"
# Vendor packages (corporate agents, Docker, Edge, local .debs) stay unless
# the drop list names them
# shellcheck disable=SC2086
apt_foreign="$(origin_foreign $apt_candidates | sort -u)"
apt_remove="$(comm -23 <(printf '%s\n' "$apt_candidates" | sed '/^$/d' | sort -u) <(printf '%s\n' "$apt_foreign"))"
apt_remove="$( { printf '%s\n' "$apt_remove"; dpkg-query -W -f '${Package}\n' | grep -E "$drop" || true; } | sed '/^$/d' | sort -u)"

log "apt: packages to remove: installed by hand or dropped tool families ($(printf '%s' "$apt_remove" | grep -c . || true))"
printf '%s\n' "$apt_remove" | column -c 120 | sed 's/^/    /'
if [ -n "$apt_foreign" ]; then
  log "apt: kept, installed from outside Ubuntu's archive (add to scripts/cleanup.d/drop-packages.list to remove)"
  printf '%s\n' "$apt_foreign" | column -c 120 | sed 's/^/    /'
fi

# They are marked "automatically installed" and autoremove deletes what no
# remaining package needs (a plain purge would also remove packages that
# depend on them, e.g. the libvirt daemon on libvirt-clients). The dry run
# simulates this on a copy of apt's state.
states="$(mktemp)"
cp /var/lib/apt/extended_states "$states" 2>/dev/null || true
for pkg in $apt_remove; do
  arch="$(dpkg-query -W -f '${Architecture}' "$pkg" 2>/dev/null || echo amd64)"
  printf 'Package: %s\nArchitecture: %s\nAuto-Installed: 1\n\n' "$pkg" "$arch" >> "$states"
done
apt_purged="$(apt-get -s -o Dir::State::extended_states="$states" autoremove --purge 2>/dev/null | awk '/^Purg /{print $2}' | sort -u)"
rm -f "$states"
# autoremove keeps a package that satisfies a Recommends of a remaining one
# (e.g. Chrome provides www-browser). Purge those explicitly, but only if
# nothing outside the planned set would go with them.
apt_explicit=""
apt_held=""
for pkg in $(comm -23 <(printf '%s\n' "$apt_remove" | sort -u) <(printf '%s\n' "$apt_purged" | sort -u)); do
  gone="$(apt-get -s purge "$pkg" 2>/dev/null | awk '/^(Purg|Remv) /{print $2}' | sort -u)"
  extra="$(comm -23 <(printf '%s\n' "$gone") <(printf '%s\n%s\n' "$apt_remove" "$apt_purged" | sort -u))"
  if [ -z "$extra" ]; then
    apt_explicit="$apt_explicit $pkg"
    apt_purged="$(printf '%s\n%s\n' "$apt_purged" "$gone" | sort -u)"
  else
    apt_held="$apt_held"$'\n'"$pkg (would also remove: $(echo $extra))"
  fi
done
log "apt: everything that goes, including dependencies nothing else needs ($(printf '%s' "$apt_purged" | grep -c . || true))"
printf '%s\n' "$apt_purged" | column -c 120 | sed 's/^/    /'
if [ -n "$apt_held" ]; then
  log "apt: kept, other packages need them"
  printf '%s\n' "$apt_held" | sed '/^$/d; s/^/    /'
fi

# --- 2. apt repositories no longer used ----------------------------------------
# Compared by repository URL. A repository stays while a remaining package
# is installed from it; files set up by a package go with that package.
remaining="$(dpkg-query -W -f '${Package}\n' | sort -u | comm -23 - <(printf '%s\n' "$apt_purged" | sort -u))"
norm() { sed -E 's|^https?://||; s|/+$||'; }
# "<repository URL> <package>" for every remaining package
# shellcheck disable=SC2086
used="$(apt-cache policy $remaining 2>/dev/null | awk '
  /^[^ ].*:$/ { pkg = substr($0, 1, length($0) - 1) }
  /\*\*\*/ { getline; if ($2 ~ /:\/\//) print $2, pkg }' | sed -E 's|^https?://||; s|/+ | |' | sort -u -k1,1)"
repos_remove=()
repos_kept=()
for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
  [ -e "$f" ] || continue
  case "$f" in *graphics-drivers*|*nvidia*|*cuda*) repos_kept+=("$f (drivers)"); continue ;; esac
  owner="$(dpkg -S "$f" 2>/dev/null | cut -d: -f1 || true)"
  if [ -n "$owner" ]; then
    printf '%s\n' "$apt_purged" | grep -qx "$owner" && repos_remove+=("$f (with $owner)")
    continue
  fi
  uris="$(grep -hoE 'https?://[^ ]+' "$f" | norm | sort -u || true)"
  [ -n "$uris" ] || continue
  why="$(awk 'NR==FNR { u[$1]; next } ($1 in u) { print $2; exit }' <(printf '%s\n' "$uris") <(printf '%s\n' "$used"))"
  if [ -z "$why" ]; then repos_remove+=("$f"); else repos_kept+=("$f (still used by $why)"); fi
done
log "apt: repositories to remove (${#repos_remove[@]})"
for f in "${repos_remove[@]}"; do item "$f"; done
log "apt: third-party repositories kept"
for f in "${repos_kept[@]}"; do item "$f"; done

# --- 3. snaps and flatpaks ----------------------------------------------------
snaps_remove="$(snap list 2>/dev/null | awk 'NR>1{print $1}' | grep -vE "$snap_keep" || true)"
log "snaps to remove (Nix provides them)"
printf '%s\n' "$snaps_remove" | sed '/^$/d; s/^/    /'
flatpaks="$(flatpak list --app --columns=application 2>/dev/null || true)"
log "flatpaks to remove (then Flatpak itself goes with apt)"
printf '%s\n' "$flatpaks" | sed '/^$/d; s/^/    /'

# --- 4. home: old tools and leftovers -----------------------------------------
home_remove=()
while IFS= read -r entry; do
  # entries may contain "*": expand against $HOME
  while IFS= read -r p; do
    [ -n "$p" ] && [ -e "$HOME/$p" ] && home_remove+=("$p")
  done < <(cd "$HOME" && compgen -G "$entry" || true)
done < <(list_entries home-leftovers.list)
# VS Code: old copies of extensions that Home Manager now provides
for d in "$HOME"/.vscode/extensions/*-[0-9]*; do
  [ -d "$d" ] && [ ! -L "$d" ] || continue
  id="$(basename "$d" | sed -E 's/-[0-9][0-9.]*(-[a-z0-9_-]+)?$//')"
  [ -L "$HOME/.vscode/extensions/$id" ] && home_remove+=("${d#"$HOME"/}")
done
log "home: old tools and leftovers (${#home_remove[@]}; Home Manager's links inside are kept)"
for p in "${home_remove[@]}"; do item "~/$p"; done
pwa="$(grep -l '/opt/google/chrome/google-chrome' "$HOME"/.local/share/applications/chrome-*.desktop 2>/dev/null || true)"
log "Chrome web app launchers to point at Nix's Chrome"
printf '%s\n' "$pwa" | sed '/^$/d; s/^/    /'

# --- 5. system: hand installs in /usr/local and /opt -------------------------
sys_remove=()
while IFS= read -r entry; do
  while IFS= read -r p; do
    [ -n "$p" ] && [ -e "$p" ] && sys_remove+=("$p")
  done < <(compgen -G "$entry" || true)
done < <(list_entries system-leftovers.list)
# dead links left by removed packages
while IFS= read -r l; do sys_remove+=("$l"); done < <(find /usr/bin /usr/local/bin -maxdepth 1 -xtype l 2>/dev/null)
log "system: hand installs and dead links (${#sys_remove[@]})"
for p in "${sys_remove[@]}"; do item "$p"; done
grep -q '^WLR_NO_HARDWARE_CURSORS=' /etc/environment && { log "/etc/environment"; item "remove WLR_NO_HARDWARE_CURSORS (ignored by Hyprland)"; }

$apply || { printf '\nDry run. Apply with: %s --apply\n' "$0"; exit 0; }

if ! $assume_yes; then
  printf '\nRemove all of the above? Type "yes": '
  read -r answer < /dev/tty
  [ "$answer" = "yes" ] || die "aborted"
fi

log "Removing flatpaks and snaps"
for a in $flatpaks; do flatpak uninstall -y --delete-data "$a" || true; done
for s in $snaps_remove; do sudo snap remove --purge "$s" || true; done

log "Removing apt packages"
if [ -n "$apt_remove" ]; then
  # shellcheck disable=SC2086
  sudo apt-mark auto $apt_remove >/dev/null
  sudo env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y
  # shellcheck disable=SC2086
  [ -z "$apt_explicit" ] || sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y $apt_explicit
  sudo env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y
fi
for f in "${repos_remove[@]}"; do
  f="${f%% (*}"
  [ -e "$f" ] && sudo rm -f "$f" "$f.save"
done
# Seen once in the test VM: after removing the Firefox snap, systemd-resolved
# had lost the DNS servers NetworkManager gave it. Re-sync if lookups fail.
if ! getent hosts archive.ubuntu.com >/dev/null; then
  log "Name resolution failed; restarting NetworkManager to re-sync DNS"
  sudo systemctl restart NetworkManager
  for _ in $(seq 1 15); do getent hosts archive.ubuntu.com >/dev/null && break; sleep 2; done
  getent hosts archive.ubuntu.com >/dev/null || echo "warning: DNS still failing; check the network" >&2
fi
sudo apt-get update -qq

log "Removing hand installs"
if [ -e /usr/local/lib/systemd/system/keyd.service ]; then
  sudo systemctl disable keyd 2>/dev/null || true
fi
for p in "${sys_remove[@]}"; do sudo rm -rf "$p"; done
sudo systemctl daemon-reload
if grep -q '^WLR_NO_HARDWARE_CURSORS=' /etc/environment; then
  { grep -v '^WLR_NO_HARDWARE_CURSORS=' /etc/environment || true; } | sudo tee /etc/environment.new >/dev/null
  sudo mv /etc/environment.new /etc/environment
fi
# system-manager's keyd takes over the unit name again
sudo systemctl restart system-manager.target 2>/dev/null || true

log "Cleaning up home"
# Never touch Home Manager's own files (links into the Nix store): inside a
# listed directory only the other entries go, the directory if then empty.
from_nix() { case "$(readlink -f "$1")" in /nix/store/*) true ;; *) false ;; esac; }
for p in "${home_remove[@]}"; do
  target="${HOME:?}/$p"
  from_nix "$target" && continue
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    find "$target" -mindepth 1 -maxdepth 1 | while read -r entry; do
      from_nix "$entry" || rm -rf "$entry"
    done
    rmdir "$target" 2>/dev/null || true
  else
    rm -rf "$target"
  fi
done
for f in $pwa; do sed -i 's|/opt/google/chrome/google-chrome|google-chrome-stable|' "$f"; done

log "Done: fresh Ubuntu + Nix. Log out and back in."
