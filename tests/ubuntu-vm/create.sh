#!/usr/bin/env bash
# Create a fresh Ubuntu 22.04 GNOME VM ("ubuntu") on this host to test the
# Ubuntu install end to end: official cloud image + cloud-init, then
# ubuntu-desktop-minimal (GNOME, GDM) and the HWE kernel. It mirrors a freshly installed
# laptop: user Alex (UID 1001), the corporate root CAs of this host, nothing
# else. Networking as for the NixOS VM: user-mode NIC for internet (works
# behind Zscaler), host-only NIC for SSH at 192.168.123.11.
#
# Usage: tests/ubuntu-vm/create.sh        (recreates the VM if it exists)
set -euo pipefail

name=ubuntu
images="${VM_IMAGES:-$HOME/VMs}"
base="$images/jammy-server-cloudimg-amd64.img"
disk="$images/$name.qcow2"
seed="$images/$name-seed.iso"
virsh=(virsh -c qemu:///system)
lan_mac=52:54:00:12:34:57
wan_mac=52:54:00:ab:cd:57
pubkey="$(cat "$HOME/.ssh/id_ed25519.pub")"

mkdir -p "$images"
[ -f "$base" ] || curl -fsSL -o "$base" https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

if "${virsh[@]}" dominfo "$name" >/dev/null 2>&1; then
  "${virsh[@]}" destroy "$name" >/dev/null 2>&1 || true
  "${virsh[@]}" undefine "$name" --nvram >/dev/null
fi
rm -f "$disk" "$seed"
qemu-img create -q -f qcow2 -F qcow2 -b "$base" "$disk" 100G

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

{
  cat <<EOF
#cloud-config
hostname: ubuntu-test
users:
  - name: Alex
    uid: 1001
    gecos: Alex Borgognoni
    shell: /bin/bash
    groups: [adm, sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    passwd: $(openssl passwd -6 password)
    ssh_authorized_keys: ["$pubkey"]
ca_certs:
  trusted:
EOF
  for crt in /usr/local/share/ca-certificates/*.crt; do
    [ -f "$crt" ] || continue
    echo "    - |"
    # (the echo adds a final newline some certificate files lack)
    { cat "$crt"; echo; } | sed -e '/^$/d' -e 's/^/      /'
  done
  cat <<'EOF'
package_update: true
packages: [ubuntu-desktop-minimal, linux-generic-hwe-22.04, openssh-server, qemu-guest-agent, spice-vdagent]
runcmd:
  # GDM: start the graphical login after the desktop install
  - systemctl set-default graphical.target
  # With the HWE kernel the boot framebuffer makes the virtio GPU card1, and
  # GDM mistakes that for GPU passthrough and disables Wayland sessions
  - ln -sf /dev/null /etc/udev/rules.d/61-gdm.rules
power_state:
  mode: reboot
  condition: true
EOF
} > "$work/user-data"

cat > "$work/network-config" <<EOF
version: 2
# NetworkManager, as on a desktop install (the cloud image defaults to
# systemd-networkd, which desktop shells like Noctalia cannot see)
renderer: NetworkManager
ethernets:
  lan:
    match: {macaddress: "$lan_mac"}
    dhcp4: true
    dhcp4-overrides: {use-routes: false, use-dns: false}
  wan:
    match: {macaddress: "$wan_mac"}
    dhcp4: true
EOF
printf 'instance-id: %s-%s\nlocal-hostname: ubuntu-test\n' "$name" "$(date +%s)" > "$work/meta-data"

cloud-localds -N "$work/network-config" "$seed" "$work/user-data" "$work/meta-data"

virt-install --connect qemu:///system --name "$name" \
  --memory 20480 --vcpus 8 --cpu host-passthrough --machine q35 \
  --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.fd,loader_secure=no \
  --osinfo ubuntu22.04 \
  --disk "path=$disk,bus=virtio" --disk "path=$seed,device=cdrom" \
  --network "user,model=virtio,mac=$wan_mac" --network "network=hostonly,model=virtio,mac=$lan_mac" \
  --graphics spice --video virtio --channel spicevmc \
  --import --noautoconsole

echo "VM '$name' created; cloud-init installs GNOME and reboots (10-20 min)."
echo "SSH: ssh Alex@192.168.123.11"
