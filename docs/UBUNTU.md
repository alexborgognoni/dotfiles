# Ubuntu (work laptop): runbook

Everything on an Ubuntu machine except what Nix cannot provide is Nix. Tested
end to end in a fresh Ubuntu 22.04 GNOME VM (`tests/ubuntu-vm/create.sh`,
checked by `tests/ubuntu-vm/verify.sh`).

Who owns what:

| Layer | Tool | Where |
|---|---|---|
| only what Nix can't provide here: Docker, libvirt/QEMU/OVMF, the zsh binary, Zscaler's Qt 6 libraries (and their Wayland plugin), Edge (corporate); groups, login shell | a short script with plain lists | `scripts/apt-layer.sh`, `apt/` |
| `/etc` and system services: Nix daemon, keyd, GPU drivers for Nix apps, GDM Wayland + "Hyprland (Nix)" session, portal, lock screen, Bluetooth/IPv4/inotify/uinput tweaks | system-manager | `nix/systems/work-laptop.nix`, `nix/modules/system-manager` |
| everything else: shell, tools, apps (Chrome, VS Code, ...), Neovim (AstroNvim), PipeWire, identities, GNOME basics (clock, input sources, touchpad), Hyprland + Noctalia, session apps, monitor layouts and scales, themes | Home Manager | `nix/homes/work-laptop.nix`, `nix/modules/home` |

Untouched: Ubuntu itself, drivers, corporate software and its packages,
users. The install removes nothing from apt; the optional cleanup is below.

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
3. Nix with the official installer, set up for a corporate TLS proxy (`scripts/bootstrap-nix.sh`)
4. `scripts/apt-layer.sh` (lists in `apt/`): Docker, libvirt/QEMU/OVMF, zsh,
   Zscaler's Qt 6 libraries, Edge; docker/libvirt groups; zsh as login shell.
   It also purges snapd (so: no snaps; `apt/purge.list`) and pins it out.
   `scripts/apt-layer.sh --check` shows what is pending without root
5. system-manager: takes over `/etc/nix/nix.conf` (the installer's file is
   kept as a backup), keyd, `/run/opengl-driver`, the "Hyprland (Nix)" login
   session, portal and lock-screen helper
6. Home Manager (`home-manager switch -b hm-backup`): activates
   `nix/homes/<machine>.nix`; a file in the way is kept as `*.hm-backup`

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
- Caps Lock is Escape, Alt+hjkl are arrows (keyd; the arrows are part of the
  corporate module, `nix/modules/system-manager/corporate.nix`).
- `kitty`, `code`, `obsidian` start; NVIDIA:
  `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo -B`
  via `nix shell nixpkgs#mesa-demos`.
- Corporate tools (Zscaler, Intune, Edge, Teams) behave as before.

## Cleanup to "fresh Ubuntu + Nix" (optional, after Hyprland works for you)

```sh
~/dotfiles/scripts/cleanup-ubuntu.sh           # dry run: lists everything
~/dotfiles/scripts/cleanup-ubuntu.sh --apply   # removes it (asks once)
```

Removes what is installed outside Nix and not part of the original Ubuntu
installation, `apt/` or the protect list: apt packages installed
by hand (CLI tools, apps, build libraries, databases, VirtualBox) and their
now unused dependencies and repositories, snaps, Flatpaks, Homebrew, pip/npm/cargo/mise
installs in your home, hand installs in `/usr/local` and `/opt`. Packages from
vendor repositories (corporate agents) are kept automatically. Requires the
snapshot. What stays and what goes is plain-text lists you can extend, see
[scripts/README.md](../scripts/README.md).

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
  (Control Center, wallpaper, session, the plugin panels) were transparent
  too (an attached panel inherits the bar's opacity). They are floating and
  solid instead (`shell.panel.*_placement`, `transparency_mode`). Panels with a
  keybinding (launcher, clipboard, session menu, keybind cheatsheet, Hyprland
  Settings) open centered, from the key and from the bar alike; the others
  open right below the clicked bar widget (`open_near_click`).
- **AirPods**: the Noctalia community plugin `harveywuk/airpods` (pinned) with a
  patched librepods daemon (`nix/packages/librepods-daemon`) as the user service
  `librepods`; enabled with `my.desktop.airpods.enable`. The case level only
  shows after a bud has been docked in the case (the AirPods do not send it
  otherwise) and is forgotten when the daemon restarts or the buds reconnect.
- **Noctalia plugins** (`my.desktop.noctalia.plugins`, catalog in
  `nix/modules/home/desktop/noctalia/plugin-catalog.nix`): Bitwarden (`/bw` in the
  launcher; `bw serve` locks after 30 minutes), File Search (`/fs`), Keybind
  Cheatsheet (Super+F1), NVTOP (GPU load in the bar, click for the process
  list), Pomodoro (Super+Ctrl+P), Color Picker (bar icon in the tools pill:
  click to open, right click to pick a color straight to the clipboard;
  hyprpicker), Emoji & Symbol Picker (Super+.), AirPods, Notes (launcher only:
  `/nt buy milk` adds to the scratchpad, bare `/nt` lists the notes; plain
  markdown files in `~/Documents/Notes`), Printers (CUPS: appears in the tools
  pill with a queued job or a stopped printer), Gamer Mode (below) and Hyprland
  Settings (below) and Voxtype (Voice dictation, below). Each is pinned to the newest revision the packaged
  Noctalia can load, with its tools from Nix. Skipped on purpose: screen
  recorder and OBS Control (open OBS to record), ALS Brightness (no light
  sensor on the P1 Gen 5), Wallpaper Depth, Config Swap (it swaps Noctalia's
  settings with configurations downloaded from GitHub at runtime: the opposite
  of a declarative setup), Bookmarks (a launcher of your own shell commands,
  not browser bookmarks: floccus syncs those). MX Control (Logitech via Solaar)
  waits for the mouse: it needs the receiver plugged in, Solaar's udev rules,
  and shows a crossed-out mouse while the device is away.
- **Gamer Mode** (toggle in the tools pill, `noctalia msg plugin
  nomadcxx/gamer-mode:service all toggle`): the power profile goes to
  performance and background programs are paused with SIGSTOP (no root), all
  restored when it ends. What is paused is our own list
  (`gamerTargets` in `plugin-catalog.nix`): sync clients, torrent clients and
  the file indexer in "light"; also the browsers, VS Code and Obsidian in
  "heavy" (a frozen program's connections drop, so Teams and Outlook pause
  too). The plugin's own list is not used: it stops system services with
  pkexec and freezes language servers. Names are what `pgrep -x` sees, cut at
  15 characters.
- **Voice dictation** (`my.desktop.dictation`, `modules/home/desktop/voxtype.nix`):
  Voxtype with Whisper large-v3-turbo (pinned, in the Nix store), running
  locally on the NVIDIA GPU through Vulkan (about a second per dictation; the
  model is loaded per dictation so the GPU can sleep in between). Press
  **Super+Ctrl+V** to start, again to stop: the text is typed at the cursor
  (`wtype`), or copied when typing is not possible. The Noctalia "voxtype"
  widget in the tools pill shows the state and also toggles on click. A toggle
  rather than hold-to-talk: text typed while the key's modifiers are still held
  comes out as shortcuts. Why it is built this way: the daemon uses its own
  ALSA configuration (PipeWire; Nix's ALSA cannot use Ubuntu's `/etc/alsa`) and
  needs `vulkaninfo` on its PATH to pick the NVIDIA GPU (otherwise it silently
  runs on the Intel one, six times slower). It replaced OpenWhispr, whose
  Hyprland hotkeys it registers at runtime and writes into a config that is
  read-only here.
- **Typing other layouts' characters** without switching the keyboard: Super+.
  opens the emoji picker, whose "Characters" tab starts with ä ö ü ß é è ê à ç
  î ï ô ù û ÿ œ æ (German and French first, then the other Latin letters and
  the quotation marks «»„“”). Search them as you would say them: `a umlaut`,
  `e acute`, `sharp s` or `eszett`, `c cedilla`, `oe`, `german`, `french`,
  `guillemet`. Enter copies the character (paste with Ctrl+V); what you pick
  often rises into "Frequently Used". The plugin's dataset is extended by
  `plugin-patches/latin-letters.py` (names and keywords from Unicode data).
- **Hyprland Settings** (plugin, bar button left of the shortcuts button,
  `/hyprland`): displays (only valid resolutions, refresh rates and scales),
  input, look, with a 15 s keep-or-revert. A kept change goes to
  `~/.config/hypr/hyprland-settings.lua` (state, not in git), which is loaded
  last. Display changes last until kanshi applies a profile again (login,
  plug, unplug); permanent values belong in `nix/homes/<machine>.nix`.
- **Screen scale** is the one lever for the size of everything (windows, bar,
  text, cursor): the `scales` table at the top of `nix/homes/work-laptop.nix`.
  Valid values give whole logical pixels (laptop panel: 1.0, 1.25, 1.6, 2.0);
  Hyprland rounds anything else. Fonts are set once, in points, in the theme.
- **Session start**: autostarted apps wait (`wait-session`) until the session
  environment is imported and the settings portal answers with a colour
  scheme; an app that starts earlier (Chrome) stays light.
- **Main display** (`my.desktop.mainMonitors`): the first connected of the
  listed monitors (by description), else the internal panel. It keeps the full
  bar and workspaces 1-10; the other displays get a workspaces-only bar and
  the leftover workspaces (11, 12, ...). `monitor-roles` does it, started by
  Hyprland on start/plug/unplug, by Noctalia's `started` hook and after a
  switch; it runs one copy at a time, moves workspaces 1-10 that have windows
  to the main display (never empty ones: Hyprland would create a replacement
  at once and the two would ping-pong), parks every other display on a
  high-numbered empty workspace (11, 12, ...) and leaves the bars alone when
  nothing changed.
  `Super+B` hides/shows all bars, `Super+Shift+B` the one on the focused
  display (`toggle-bar`, aware of which bar each display shows). Do not call
  `hl.workspace_rule` from event handlers or listen to
  `monitor.layout_changed`/`config.reloaded` for this: it re-applies the
  monitor setup in a loop (every screen flashes).
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
- **Entra SSO in Firefox and Zen** (Nix) works the same way: the host is made
  known to the browser (Zen, a Firefox fork, reads the same
  `~/.mozilla/native-messaging-hosts`) and the signed extension of the same
  release is installed with the profile (`modules/home/corporate/entra-sso.nix`). Host and extension must be
  the same version (the Chrome extension updates itself from the Web Store, so
  bump the package when it moves; update steps are in the package's header).
  Once, in each of them: click the extension's icon and allow "Access your data for
  login.microsoftonline.com". SSO is per container, on in the default one.
  Test: `linux-entra-sso --interactive getAccounts` from the package prints the
  broker's accounts (Intune must be signed in).

## Sound: back to PulseAudio

PipeWire is the default; PulseAudio stays installed. To switch back, set
`my.audio.server = "pulseaudio";` in `nix/homes/work-laptop.nix`,
`nh home switch`, log out and in.

## Things to check once on the laptop

- Monitor layouts (kanshi): laptop alone, home (Lenovo above), desk (MSI
  rotated left, ROG, laptop); the MSI rotation direction may need flipping.
- Zscaler: the tray is a Qt 6 WebEngine app linked against the system Qt
  (`apt/packages.list`: the `libqt6*` packages, which autoremove once took
  away; `qt6-wayland` makes its window native Wayland instead of a blurry
  XWayland one). Zscaler's own menu entry took itself for an already running
  tray and aborted; "Zscaler Client Connector" from
  `nix/modules/home/corporate/zscaler.nix` replaces it and opens the window of a running
  tray. The tray registers its icon only at start, so the unit waits for
  Noctalia's tray (`zscaler-tray.service.d`). Hyprland starts it at login
  (`my.desktop.autostart`); the GNOME session uses Zscaler's own autostart
  entry. Check after a reboot: `systemctl --user status zscaler-tray`.
- Readest: select the custom theme "Theme" once; it follows `theme` from
  then on (applied when Readest starts).
- herdr: `herdr integration install` for opencode, if its files are missing.

## Rollback

```sh
home-manager generations                       # pick an earlier one, run its ./activate
sudo system-manager deactivate                 # system level (restores nix.conf etc.)
```

Nix stays installed (uninstall: `sudo /nix/nix-installer uninstall`). apt
packages added by `apt-layer.sh` stay; the login shell goes back with
`chsh -s /bin/bash`. The snapshot in `~/Backups` has the old files.
