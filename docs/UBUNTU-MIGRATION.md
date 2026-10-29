# Ubuntu work laptop: switch from chezmoi to Nix

Runbook for phase 3 of [NIX-PLAN.md](NIX-PLAN.md). Rehearsed in a Ubuntu
22.04 container that reproduces this laptop (`scripts/test-ubuntu-hm.sh`,
including the rollback) and end to end in a fresh Ubuntu 22.04 GNOME VM
(`tests/ubuntu-vm/create.sh`, checked by `tests/ubuntu-vm/verify.sh`).

Who owns what afterwards:

| Layer | Tool | Where |
|---|---|---|
| only what Nix can't provide here: Docker, libvirt/QEMU, the zsh binary, Edge (corporate); groups, login shell | Ansible (slim) | `ansible/ubuntu.yml` |
| `/etc` and system services: Nix daemon, keyd, GPU drivers for Nix apps, GDM Wayland + "Hyprland (Nix)" session, portal, lock screen, Bluetooth/IPv4/inotify/uinput tweaks | system-manager | `nix/systems/work-laptop.nix`, `nix/modules/system-manager` |
| everything else: shell, tools, apps (Chrome, VS Code, ...), Neovim (AstroNvim), PipeWire, identities, GNOME basics (clock, input sources, touchpad), Hyprland + Noctalia, session apps, monitor layouts, themes | Home Manager | `nix/homes/work-laptop.nix`, `nix/modules/home` |

Untouched: Ubuntu itself, drivers, corporate software and its packages,
users. Nothing is removed from apt.

## Before you start

- [ ] Installing Nix on this machine is acceptable to you / your company.
- [ ] The sops admin key `~/.config/sops/age/keys.txt` is backed up
      (Bitwarden item `sops-age-key`). It decrypts your SSH/GPG keys.
- [ ] ~40 GB free disk space (the first build downloads about 27 GB).

## Snapshot (automatic, once)

The installer takes it right after installing Nix, before anything else
changes (`scripts/snapshot-system.sh`, also usable on its own): one archive
in `~/Backups`, encrypted to your sops admin key, with `~/.config` (without
browser caches), `~/.local/bin`, snap/flatpak data, shell dotfiles and
history, all of `/etc`, and the lists of everything installed (apt, snap,
flatpak, pip, npm, cargo, /opt, /usr/local). Copy it off the machine
(OneDrive). Restore a file:
`age -d -i ~/.config/sops/age/keys.txt <archive> | zstd -d | tar -x <path>`.

## Install (one command, asks for sudo once)

```sh
DOTFILES_BRANCH=nixos ~/dotfiles/install
# fresh machine: curl -fsSL https://raw.githubusercontent.com/alexborgognoni/dotfiles/nixos/install | DOTFILES_BRANCH=nixos bash
```

1. updates `~/dotfiles`
2. sops admin key (existing file, `$SOPS_AGE_KEY`, Bitwarden, or pasted)
3. Nix with the official installer, set up for Zscaler (`scripts/bootstrap-nix.sh`)
4. `ansible/ubuntu.yml`: Docker, PipeWire, zsh, Chrome, Edge, GNOME
   extension and icon packages; docker group; zsh as login shell
5. system-manager: takes over `/etc/nix/nix.conf` (the installer's file is
   kept as a backup), keyd, `/run/opengl-driver`, the "Hyprland (Nix)" login
   session, portal and lock-screen helper
6. Home Manager (`scripts/migrate-to-home-manager.sh`): moves every
   chezmoi-managed file, `~/.config/nvim`, the old GNOME extension folders
   and binaries Nix now provides into
   `~/.local/state/dotfiles-migration/<timestamp>/`, then activates

Then log out and back in.

## Check

- GNOME session: plain Ubuntu GNOME (the backup session): no Shell extensions or custom keybindings; only the basic preferences from `nix/modules/home/gnome`.
- Login screen gear menu: "Hyprland (Nix)" starts Hyprland with Noctalia;
  `theme` / the Noctalia theme picker switch themes live; Super+Escape locks,
  your password unlocks (the lock screen starts in the first keyboard layout,
  US; Super+Space switches, see "Hyprland session notes").
- Sound works in both sessions (PipeWire; `pactl info` shows
  "PulseAudio (on PipeWire …)").
- New terminal: zsh, prompt, aliases, `theme` work.
- `git config user.email` is the work address; in `~/dotfiles` and
  `~/personal/*` it is the personal one; commits are signed.
- `ssh -T git@github.com` (personal key) and GitHub Enterprise (work key).
- Caps Lock is Escape, Alt+hjkl are arrows (keyd).
- `kitty`, `code`, `obsidian` start; NVIDIA:
  `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo -B`
  via `nix shell nixpkgs#mesa-demos`.
- Corporate tools (Zscaler, Intune, Edge, Teams) behave as before.

## Cleanup to "fresh Ubuntu + Nix" (after Hyprland works for you)

```sh
~/dotfiles/scripts/cleanup-ubuntu.sh           # dry run: lists everything
~/dotfiles/scripts/cleanup-ubuntu.sh --apply   # removes it (asks once)
```

Removes what is installed outside Nix and not part of the original Ubuntu
installation, `ansible/ubuntu.yml` or the protect list (corporate agents,
drivers, kernels, system parts): ~170 apt packages (CLI tools, apps, build
libraries, TeX, Wine, CUDA, the PostgreSQL/MySQL servers, VirtualBox) and
their now unused dependencies and repositories, the chromium/firefox/teams
snaps, OBS (Flatpak), pip/npm/cargo/mise/nvm installs in your home, hand
installs in `/usr/local` and `/opt`. Chrome web app launchers are pointed at
Nix's Chrome. Requires the snapshot. Databases and CUDA now come per project
(dev shells or containers).

## Everyday use afterwards

```sh
nh home switch                                              # user level
sudo system-manager switch --flake ~/dotfiles/nix#work-laptop   # system level
nh home switch --update                                     # update everything (flake.lock)
~/dotfiles/install                                          # all layers, idempotent
```

When apt upgrades the NVIDIA driver, `nh home switch` warns; update
`my.gpu.nvidia.version` and `sha256` in `nix/homes/work-laptop.nix` (the
warning says how), then run both switches.

## Hyprland session notes

- **Keyboard layouts** (`my.keyboard.layout = "us,gb"`): Hyprland keeps the
  layout per keyboard device, so xkb toggles (`grp:alt_shift_toggle`) only
  switch the keyboard they were pressed on, and Noctalia's label follows yet
  another device. That desynchronised the lock screen (a password typed the
  US way came out as GB). Layouts are therefore switched for all keyboards at
  once: Super+Space (`hyprctl switchxkblayout all next`, also on the lock
  screen) or Noctalia's layout button. Do not add `grp:` options.
- **Lock screen**: Noctalia authenticates against its own PAM service
  (`/etc/pam.d/noctalia`, from the system layer), because Nix's PAM cannot read
  Ubuntu's `@include` files, with the setuid helper at
  `/run/wrappers/bin/unix_chkpwd`. Locked out: Ctrl+Alt+F3, log in,
  `loginctl unlock-session`.
- **Panels**: the bar is transparent, so panels that opened attached to it
  (Control Center, wallpaper, session, the AirPods plugin panel) were
  transparent too (an attached panel inherits the bar's opacity). They are
  floating and solid instead (`shell.panel.*_placement`,
  `transparency_mode`) and open right below the bar widget that was clicked
  (`open_near_click`). Clipboard and launcher stay centered.
- **AirPods**: the Noctalia community plugin `harveywuk/airpods` (pinned) with a
  patched librepods daemon (`nix/packages/librepods-daemon`) as the user service
  `librepods`; enabled with `my.desktop.airpods.enable`. The case level only
  shows after a bud has been docked in the case (the AirPods do not send it
  otherwise) and is forgotten when the daemon restarts or the buds reconnect.
- **Digital audio outputs** (S/PDIF, USB card profiles): Noctalia lists only
  active devices, GNOME Settings also switches card profiles. Pick the output
  once there (`XDG_CURRENT_DESKTOP=GNOME gnome-control-center sound`; the entry
  is hidden under Hyprland); WirePlumber remembers it.
- **sudo**: passwordless only for apt, apt-get, systemctl and tee
  (`/etc/sudoers.d/010-alex-nopasswd`). kitty's `sudo` wrapper (it runs
  `sudo TERMINFO=...`) is switched off (`shell_integration ... no-sudo`),
  because sudoers refuses that for allow-listed commands.
- **tmux** is 3.8 (nixpkgs unstable); the status-line prompt colors are
  re-applied after every `theme` switch (`modules/home/terminal/tmux.nix`).
- **Chrome** (Nix) trusts the corporate CA through the `chrome-corporate-cas`
  system service and signs in through the packaged Entra SSO helper
  (`nix/packages/linux-entra-sso`), also for the Claude Code native host.

## Sound: back to PulseAudio

PipeWire is the default; PulseAudio stays installed. To switch back, set
`my.audio.server = "pulseaudio";` in `nix/homes/work-laptop.nix`,
`nh home switch`, log out and in.

## Things to check once on the laptop

- Monitor layouts (kanshi): laptop alone, home (Lenovo above), desk (MSI
  rotated left, ROG, laptop); the MSI rotation direction may need flipping.
- Zscaler tray icon in Noctalia's tray under Hyprland. The tray is a Qt 6
  WebEngine app linked against the system Qt (`ansible/ubuntu.yml`: the
  `libqt6*` packages), because it is not an apt package and autoremove once
  took those libraries away (`ZSTray: error while loading shared libraries`,
  then `Could not find QtWebEngineProcess`). Zscaler's own menu entry took
  itself for an already running tray and aborted; it is replaced by
  "Zscaler Client Connector" from `nix/modules/home/work.nix`. Hyprland starts
  the tray at login (`my.desktop.autostart`, after Noctalia); the GNOME
  session uses Zscaler's own autostart entry. Check after a reboot:
  `systemctl --user status zscaler-tray`.
- Readest: select the custom theme "Theme" once; it follows `theme` from
  then on (applied when Readest starts).
- herdr: `herdr integration install` for opencode, if its files are missing.

## Rollback

```sh
~/dotfiles/scripts/rollback-to-chezmoi.sh                       # user level
sudo system-manager deactivate                                  # system level (restores nix.conf etc.)
```

The first removes the Home Manager generation and restores the backed-up
files and binaries. Nix stays installed (uninstall: `sudo /nix/nix-installer
uninstall`). apt packages added by Ansible stay; the login shell goes back
with `chsh -s /bin/bash`.

## Later (after you sign off)

- remove duplicate apt/snap/flatpak installs and their apt repositories
  (corporate and OS packages are never touched)
- retire chezmoi, the old Ansible roles and `scripts/install-legacy.sh`
