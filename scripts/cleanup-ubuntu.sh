#!/usr/bin/env bash
# After the migration: remove everything installed outside Nix that Nix now
# provides, so the machine is "fresh Ubuntu + Nix". What stays is declared:
#   - packages of the original Ubuntu installation (/var/log/installer)
#   - ansible/ubuntu.yml (root daemons and the login shell)
#   - the protect list below (corporate software, drivers, system parts)
# Everything removed is in the snapshot (scripts/snapshot-system.sh), which
# must exist first.
#
#   scripts/cleanup-ubuntu.sh            dry run: shows what would be removed
#   scripts/cleanup-ubuntu.sh --apply    removes it (asks once, needs sudo)
set -euo pipefail

apply=false
[ "${1:-}" = "--apply" ] && apply=true
dotfiles="$(cd "$(dirname "$0")/.." && pwd)"

# Never removed (regexes on package names): corporate agents and their
# repositories, drivers, kernels, firmware, OEM, smartcards, system parts.
protect='^(falcon-sensor|icaclient|intune-portal|microsoft-.*|packages-microsoft-prod|ud-agent|zscaler.*|cisco.*|oem-.*|linux-.*|nvidia-.*|libnvidia-.*|realtek-.*|firmware-.*|opensc|libnss-resolve|systemd-coredump|iw|ubuntu-.*)$'
# Dropped tool families: removed completely, including parts that were
# installed as dependencies (servers now run per project, CUDA per project)
drop='^(postgresql|postgresql-[0-9].*|postgresql-common|postgresql-client.*|mysql-.*|virtualbox.*|cuda-.*)$'
# Snaps of the Ubuntu installation that stay (store, printing, desktop glue)
snap_keep='^(bare|core[0-9]*|snapd|snap-store|snapd-desktop-integration|cups|lxd|gnome-[0-9-]+|gtk-common-themes|mesa-[0-9]+)$'

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
item() { printf '    %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

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
apt_remove="$(apt-mark showmanual | sort -u \
  | comm -23 - <(printf '%s\n' "$initial") \
  | comm -23 - <(printf '%s\n' "$declared") \
  | grep -vE "$protect" || true)"
apt_remove="$( { printf '%s\n' "$apt_remove"; dpkg-query -W -f '${Package}\n' | grep -E "$drop" || true; } | sed '/^$/d' | sort -u)"

log "apt: packages to remove: installed by hand or dropped tool families ($(printf '%s' "$apt_remove" | grep -c . || true))"
printf '%s\n' "$apt_remove" | column -c 120 | sed 's/^/    /'

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
for p in .local/bin .local/lib/python3.10 .nvm .local/share/mise .config/mise .pyenv .opencode .bun \
         .local/share/fonts .icons .local/share/themes/catppuccin-macchiato-lavender-standard+default \
         .local/share/themes/catppuccin-macchiato-lavender-standard+default-hdpi \
         .local/share/themes/catppuccin-macchiato-lavender-standard+default-xhdpi \
         .local/share/applications/kitty.desktop .local/share/applications/kitty-open.desktop \
         .local/share/applications/me.kavishdevar.librepods.desktop \
         .config/envman .config/herd-lite .config/composer .config/psysh .config/neofetch \
         .config/touchegg .config/VirtualBox .config/BraveSoftware .config/opera .config/vivaldi \
         .config/chromium .config/chezmoi .local/share/chezmoi \
         .brewenv_cache .zinit .local/share/zinit .tmux/plugins; do
  [ -e "$HOME/$p" ] && home_remove+=("$p")
done
for b in loc neovide resvg squawk yazi ya yazi-build; do
  [ -e "$HOME/.cargo/bin/$b" ] && home_remove+=(".cargo/bin/$b")
done
log "home: old tools and leftovers (${#home_remove[@]})"
for p in "${home_remove[@]}"; do item "~/$p"; done
pwa="$(grep -l '/opt/google/chrome/google-chrome' "$HOME"/.local/share/applications/chrome-*.desktop 2>/dev/null || true)"
log "Chrome web app launchers to point at Nix's Chrome"
printf '%s\n' "$pwa" | sed '/^$/d; s/^/    /'

# --- 5. system: hand installs in /usr/local and /opt -------------------------
sys_remove=()
for p in /usr/local/bin/aws /usr/local/bin/aws_completer /usr/local/aws-cli /usr/local/bin/bw \
         /usr/local/bin/keyd /usr/local/bin/keyd-application-mapper /usr/local/lib/systemd/system/keyd.service \
         /usr/local/bin/kubectl /usr/local/bin/lazygit /usr/local/bin/llama-cli /usr/local/bin/onedrive \
         /usr/local/bin/starship /usr/local/bin/tflint /usr/local/bin/tmux /usr/local/bin/xdotool \
         /opt/nvim-linux-x86_64; do
  [ -e "$p" ] && sys_remove+=("$p")
done
log "system: hand installs (${#sys_remove[@]})"
for p in "${sys_remove[@]}"; do item "$p"; done
grep -q '^WLR_NO_HARDWARE_CURSORS=' /etc/environment && { log "/etc/environment"; item "remove WLR_NO_HARDWARE_CURSORS (ignored by Hyprland)"; }

$apply || { printf '\nDry run. Apply with: %s --apply\n' "$0"; exit 0; }

printf '\nRemove all of the above? Type "yes": '
read -r answer < /dev/tty
[ "$answer" = "yes" ] || die "aborted"

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
for p in "${home_remove[@]}"; do rm -rf "${HOME:?}/$p"; done
for f in $pwa; do sed -i 's|/opt/google/chrome/google-chrome|google-chrome-stable|' "$f"; done

log "Done: fresh Ubuntu + Nix. Log out and back in."
