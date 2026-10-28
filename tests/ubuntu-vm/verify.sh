#!/usr/bin/env bash
# Verify the Ubuntu install end to end in the test VM (tests/ubuntu-vm/create.sh,
# then ./install in it). Run from the host while the VM is logged in to
# "Hyprland (Nix)" (create.sh sets up auto-login):
#
#   tests/ubuntu-vm/verify.sh [user@host]      (default: Alex@192.168.123.11)
#
# Everything is asserted, nothing is eyeballed: system layer, GDM, network,
# audio, the Hyprland session, portals, lock screen PAM, GNOME settings,
# identities and tools. Exits non-zero if any check fails.
set -uo pipefail

target="${1:-Alex@192.168.123.11}"
pass=0
fail=0

# Runs in the VM, inside the graphical session's environment
remote() {
  ssh -o BatchMode=yes "$target" 'export XDG_RUNTIME_DIR=/run/user/$(id -u)
    export WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr 2>/dev/null | head -1)
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    export PATH=$HOME/.nix-profile/bin:$PATH
    '"$1"
}

check() {
  local name="$1" cmd="$2"
  if out="$(remote "$cmd" 2>&1)"; then
    printf '  \033[32mok\033[0m   %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  \033[31mFAIL\033[0m %s\n' "$name"
    [ -n "$out" ] && printf '%s\n' "$out" | tail -5 | sed 's/^/         /'
    fail=$((fail + 1))
  fi
}

section() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

section "System layer (Ansible, system-manager)"
check "zsh is the login shell" '[ "$(getent passwd $(id -un) | cut -d: -f7)" = /usr/bin/zsh ]'
check "docker group, docker running" 'id -nG | grep -qw docker && systemctl is-active -q docker'
check "Chrome and Edge installed (apt)" 'command -v google-chrome && command -v microsoft-edge'
check "nix.conf owned by system-manager, corporate CA" 'grep -q "ssl-cert-file = /etc/ssl/certs/ca-certificates.crt" /etc/nix/nix.conf'
check "Nix in non-interactive zsh" 'zsh -c "command -v nix"'
check "keyd running with the shared config" 'systemctl is-active -q keyd && grep -q "capslock = esc\|capslock=esc" /etc/keyd/default.conf'
check "GPU drivers linked (/run/opengl-driver)" 'test -e /run/opengl-driver/lib/gbm/dri_gbm.so'
check "setuid unix_chkpwd wrapper" 'test -u /run/wrappers/bin/unix_chkpwd'
check "users and groups untouched (no userborn)" '! systemctl cat userborn.service >/dev/null 2>&1'

section "Login screen"
check "Wayland sessions enabled in GDM" '! grep -qiE "^\s*WaylandEnable\s*=\s*false" /etc/gdm3/custom.conf'
check "\"Hyprland (Nix)\" session entry" 'grep -q "^Exec=.*hyprland-session" /usr/share/wayland-sessions/hyprland-nix.desktop'

section "Network (NetworkManager, as Noctalia sees it)"
check "NetworkManager manages a connected device" 'nmcli -t -f STATE,TYPE device | grep -qE "^connected:(ethernet|wifi)"'
check "internet through the corporate proxy chain" 'curl -fsS -o /dev/null https://cache.nixos.org'

section "Hyprland session"
check "Hyprland running" 'hyprctl version >/dev/null'
check "hyprland-session.target active" 'systemctl --user is-active -q hyprland-session.target'
check "Noctalia running (patched lock service)" 'systemctl --user is-active -q noctalia && grep -q "^noctalia$" <(strings "$(readlink -f /proc/$(systemctl --user show -p MainPID --value noctalia)/exe)")'
check "Noctalia not bound to GNOME (graphical-session.target)" '! grep -q graphical-session ~/.config/systemd/user/noctalia.service'
check "portals: ScreenCast, Screenshot, FileChooser, Settings" 'i=$(gdbus introspect --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop); for x in ScreenCast Screenshot FileChooser Settings; do grep -q "interface org.freedesktop.portal.$x" <<<"$i" || { echo "missing $x"; exit 1; }; done'
check "theme switch (nord and back)" 'before=$(theme current | cut -d" " -f1); theme apply nord >/dev/null 2>&1 && readlink ~/.local/state/theme/current | grep -q nord && theme apply "$before" >/dev/null 2>&1'

section "Session apps (my.desktop.autostart)"
check "kitty on workspace 1" 'hyprctl -j clients | jq -e "any(.[]; .class == \"kitty\" and .workspace.id == 1)" >/dev/null'
check "Chrome on workspace 2" 'hyprctl -j clients | jq -e "any(.[]; (.class | test(\"google-chrome\")) and .workspace.id == 2)" >/dev/null'
check "Teams on workspace 3" 'hyprctl -j clients | jq -e "any(.[]; (.class | test(\"teams-for-linux\")) and .workspace.id == 3)" >/dev/null'

section "Audio"
check "PipeWire is the sound server" 'timeout 5 pactl info | grep -q "on PipeWire"'
check "PipeWire and WirePlumber from Nix" 'systemctl --user show pipewire wireplumber -p ExecStart | grep -c /nix/store/ | grep -qx 2'
check "exactly one WirePlumber" '[ "$(pgrep -cx wireplumber)" = 1 ]'
check "a real output device" 'timeout 5 pactl list short sinks | grep -qv auto_null'

section "Lock screen authentication (Nix PAM, service \"noctalia\")"
check "wrong password rejected" 'p=$(nix build --no-link --print-out-paths nixpkgs#pamtester 2>/dev/null); ! echo wrong | $p/bin/pamtester noctalia $(id -un) authenticate'
check "right password accepted" 'p=$(nix build --no-link --print-out-paths nixpkgs#pamtester 2>/dev/null); echo "${VM_PASSWORD:-password}" | $p/bin/pamtester noctalia $(id -un) authenticate'

section "GNOME (settings in Home Manager)"
check "all configured extensions enabled" '[ "$(gsettings get org.gnome.shell enabled-extensions | tr , "\n" | wc -l)" -ge 15 ]'
check "Catppuccin GTK and Shell theme" 'gsettings get org.gnome.desktop.interface gtk-theme | grep -q catppuccin && dconf read /org/gnome/shell/extensions/user-theme/name | grep -q catppuccin'
check "keybindings" '[ "$(gsettings get org.gnome.desktop.wm.keybindings close)" = "['"'"'<Shift><Super>q'"'"']" ]'

section "Apps"
check "Chrome from Nix, Edge from apt" 'command -v google-chrome-stable | grep -q nix-profile && command -v microsoft-edge | grep -q ^/usr/bin'
check "Neovim (AstroNvim): no errors, live theme" 'out="$(cd /tmp && nvim --headless "+lua vim.defer_fn(function() io.stdout:write(vim.g.colors_name .. \"|\" .. vim.fn.execute(\"messages\")) vim.cmd(\"qa!\") end, 4000)" 2>&1)"; echo "$out" | grep -q "theme-" && ! echo "$out" | grep -qi error'
check "Readest colors in the theme pack" 'jq -e .colors.dark.bg ~/.local/state/theme/current/readest.json >/dev/null'
check "seeded app settings" 'test -f ~/.config/herdr/config.toml && test -f ~/.config/opencode/cli.json'

section "User environment"
check "git identity and signing" 'git -C ~/dotfiles config user.email | grep -q @ && git config --get commit.gpgsign | grep -q true'
check "GPG keys imported" '[ "$(/usr/bin/gpg --list-secret-keys --with-colons | grep -c ^sec)" -ge 1 ]'
check "tools present" 'for c in nvim tmux kitty theme nh starship; do command -v $c >/dev/null || { echo "missing $c"; exit 1; }; done'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
