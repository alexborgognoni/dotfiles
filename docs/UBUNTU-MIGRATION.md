# Ubuntu work laptop: switch from chezmoi to Nix

Runbook for phase 3 of [NIX-PLAN.md](NIX-PLAN.md). Rehearsed in a Ubuntu
22.04 container that reproduces this laptop (`scripts/test-ubuntu-hm.sh`,
including the rollback) and end to end in a fresh Ubuntu 22.04 GNOME VM
(`tests/ubuntu-vm/create.sh`, checked by `tests/ubuntu-vm/verify.sh`).

Who owns what afterwards:

| Layer | Tool | Where |
|---|---|---|
| apt repositories and packages, groups, login shell | Ansible (slim) | `ansible/ubuntu.yml` |
| `/etc` and system services: Nix daemon, keyd, GPU drivers for Nix apps, the Hyprland login session, lock-screen helper | system-manager | `nix/systems/work-laptop.nix`, `nix/modules/system-manager` |
| everything in your home: shell, tools, apps, identities, GNOME settings and extensions, Hyprland + Noctalia, themes | Home Manager | `nix/homes/work-laptop.nix`, `nix/modules/home` |

Untouched: Ubuntu itself, drivers, corporate software and its packages,
users. Nothing is removed from apt.

## Before you start

- [ ] Installing Nix on this machine is acceptable to you / your company.
- [ ] The sops admin key `~/.config/sops/age/keys.txt` is backed up
      (Bitwarden item `sops-age-key`). It decrypts your SSH/GPG keys.
- [ ] ~40 GB free disk space (the first build downloads about 27 GB).

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

- GNOME session: looks as before (Catppuccin theme, extensions, keybindings).
- Login screen gear menu: "Hyprland (Nix)" starts Hyprland with Noctalia;
  `theme` / the Noctalia theme picker switch themes live; Super+Escape locks,
  your password unlocks.
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

GNOME extensions are pinned per GNOME Shell version: to update them (or add
one), edit and run `scripts/update-gnome-extensions.sh`.

## Sound: back to PulseAudio

PipeWire is the default; PulseAudio stays installed. To switch back, set
`my.audio.server = "pulseaudio";` in `nix/homes/work-laptop.nix`,
`nh home switch`, log out and in.

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
