#!/usr/bin/env bash
# The whole Ubuntu install test, unattended (about an hour, ~30 GB of downloads):
#   1. create.sh      a fresh Ubuntu 22.04 GNOME VM ("ubuntu"; an existing one is replaced)
#   2.                wait for cloud-init (GNOME, HWE kernel) and its reboot
#   3.                put the sops admin key in the VM
#   4. ./install      run in the VM from the pushed branch, detached from the SSH
#                     connection; its log is copied to ~/ubuntu-vm-install.log
#   5.                log in to "Hyprland (Nix)" automatically (test VM only)
#   6. verify.sh      assert the result from the host
#
#   tests/ubuntu-vm/run.sh                  branch: nixos (DOTFILES_BRANCH)
#   sg libvirt -c tests/ubuntu-vm/run.sh    if your shell is not in the libvirt group yet
#
# The VM is left running for a look (SPICE or ssh Alex@192.168.123.11); shut it
# down with: virsh -c qemu:///system shutdown ubuntu
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
ip="${VM_IP:-192.168.123.11}"
target="${VM_USER:-Alex}@$ip"
branch="${DOTFILES_BRANCH:-nixos}"
keyfile="$HOME/.config/sops/age/keys.txt"
install_log="$HOME/ubuntu-vm-install.log"
ssh_opts=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o ServerAliveInterval=30 -o LogLevel=ERROR)

vm() { ssh "${ssh_opts[@]}" "$target" "$@"; }
phase() { printf '\n\033[1;34m==> [%s] %s\033[0m\n' "$(date +%H:%M:%S)" "$*"; }
die() {
  printf '\033[1;31mfailed:\033[0m %s\n' "$*" >&2
  exit 1
}

# wait_for <seconds> <what> <command...>: retry every 15 s
wait_for() {
  local limit="$1" what="$2" waited=0
  shift 2
  until "$@" >/dev/null 2>&1; do
    [ "$waited" -lt "$limit" ] || die "timed out after ${limit}s waiting for $what"
    sleep 15
    waited=$((waited + 15))
  done
}

[ -s "$keyfile" ] || die "$keyfile (the sops admin key) is missing"

phase "1/6 create the VM"
if [ -n "${SKIP_CREATE:-}" ]; then
  echo "SKIP_CREATE: using the running VM"
else
  "$here/create.sh" || die "create.sh"
fi
ssh-keygen -R "$ip" >/dev/null 2>&1 || true

phase "2/6 wait for cloud-init (GNOME, HWE kernel) and its reboot"
wait_for 3600 "the VM to accept ssh" vm true
# Done when cloud-init has finished, GDM runs, and the running kernel is the
# newest installed one: the HWE kernel only runs after the final reboot. (The VM
# may only answer ssh after that reboot, so the reboot itself is not awaited.)
installed_system_up() {
  vm 'cloud-init status | grep -q "status: done" &&
    systemctl is-active -q gdm3 &&
    [ "$(uname -r)" = "$(ls /boot/vmlinuz-* | sed "s|/boot/vmlinuz-||" | sort -V | tail -1)" ] &&
    [ "$(cut -d. -f1 /proc/uptime)" -gt 60 ]'
}
wait_for 3600 "cloud-init and the reboot" installed_system_up
echo "kernel: $(vm uname -r)"

phase "3/6 admin key"
vm 'mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age' || die "ssh"
scp "${ssh_opts[@]}" "$keyfile" "$target:.config/sops/age/keys.txt" >/dev/null || die "copying the key"
vm 'chmod 600 ~/.config/sops/age/keys.txt'

phase "4/6 ./install in the VM (branch $branch)"
vm "rm -f ~/install.exit ~/install.log; setsid nohup bash -c 'curl -fsSL https://raw.githubusercontent.com/alexborgognoni/dotfiles/$branch/install | DOTFILES_BRANCH=$branch bash; echo \$? > ~/install.exit' > ~/install.log 2>&1 < /dev/null &" || die "starting install"
shown=0
waited=0
until vm 'test -f ~/install.exit' 2>/dev/null; do
  [ "$waited" -lt 14400 ] || die "./install still running after 4 hours; see ~/install.log in the VM"
  sleep 60
  waited=$((waited + 60))
  total="$(vm 'wc -l < ~/install.log' 2>/dev/null || echo "$shown")"
  if [ "$total" -gt "$shown" ]; then
    printf '[%s] %s lines; last: %s\n' "$(date +%H:%M:%S)" "$total" "$(vm 'tail -n 1 ~/install.log' 2>/dev/null | cut -c1-110)"
    shown="$total"
  fi
done
vm 'cat ~/install.log' >"$install_log" 2>/dev/null
code="$(vm 'cat ~/install.exit')"
echo "install exited with $code (log: $install_log)"
[ "$code" = 0 ] || die "./install failed; see $install_log"

phase "5/6 log in to Hyprland (Nix)"
# GDM's file is system-manager's symlink into the Nix store: replace it with a
# plain copy plus auto-login (a test VM; the next system-manager switch restores it)
vm 'sudo rm -f /etc/gdm3/custom.conf && printf "[daemon]\nWaylandEnable=true\nAutomaticLoginEnable=true\nAutomaticLogin=$(id -un)\n" | sudo tee /etc/gdm3/custom.conf >/dev/null' || die "gdm config"
vm 'sudo mkdir -p /var/lib/AccountsService/users && printf "[User]\nSession=hyprland-nix\nXSession=hyprland-nix\nSystemAccount=false\n" | sudo tee /var/lib/AccountsService/users/$(id -un) >/dev/null' || die "session choice"
vm 'sudo systemctl restart gdm3' || die "restarting gdm3"
hyprland_up() { vm 'export XDG_RUNTIME_DIR=/run/user/$(id -u); ls $XDG_RUNTIME_DIR/hypr >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null'; }
wait_for 600 "the Hyprland session" hyprland_up
echo "session up; letting the autostart apps settle"
sleep 120

phase "6/6 verify"
"$here/verify.sh" "$target"
result=$?
echo
[ "$result" -eq 0 ] && echo "ubuntu-vm: all checks passed" || echo "ubuntu-vm: checks failed"
exit "$result"
