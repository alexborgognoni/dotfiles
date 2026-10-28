# Ubuntu work laptop: switch from chezmoi to Home Manager

Runbook for phase 3 of [NIX-PLAN.md](NIX-PLAN.md). Everything below was
rehearsed in a Ubuntu 22.04 container that reproduces this laptop
(`scripts/test-ubuntu-hm.sh`: 50 checks, including the rollback).

What changes: Nix is installed (`/nix` + the `nix-daemon` service) and Home
Manager takes over your user-level configuration and tools. What does not
change: Ubuntu, GNOME, drivers, corporate software, apt packages, system
services. Nothing is removed from apt in this phase.

## Before you start

- [ ] Installing Nix on this machine is acceptable to you / your company.
- [ ] The sops admin key `~/.config/sops/age/keys.txt` is backed up
      (Bitwarden). The migration needs it to decrypt your SSH/GPG keys.
- [ ] The branch is checked out: `git -C ~/dotfiles switch nixos`.
- [ ] ~40 GB free disk space (the first build downloads about 27 GB).

## 1. Install Nix (once, asks for sudo)

```sh
~/dotfiles/scripts/bootstrap-nix.sh
```

Installs the multi-user Nix daemon with the official installer and configures
it for Zscaler (system CA bundle for the daemon and the build sandbox), flakes,
and you as trusted user. Then open a new terminal.

## 2. Migrate

```sh
~/dotfiles/scripts/migrate-to-home-manager.sh
```

1. builds `alex@work-laptop` (nix/homes/work-laptop.nix)
2. moves every chezmoi-managed file (and `~/.config/nvim`) to
   `~/.local/state/dotfiles-migration/<timestamp>/`
3. activates Home Manager (any other conflicting file is kept as
   `<file>.hm-backup`)
4. moves binaries in `~/.local/bin` and `~/.cargo/bin` that Nix now provides
   (kitty, claude, uv, opencode, ...) into the same backup, so they don't
   shadow the Nix versions; your own scripts stay

## 3. GPU drivers for Nix GUI apps (once, sudo)

```sh
sudo $(which non-nixos-gpu-setup)
```

Then log out and back in (GNOME picks up the Nix apps in its app grid and the
new environment).

## 4. Check

- New terminal: zsh starts without errors, prompt, aliases, `theme` works.
- `git config user.email` is the work address; in `~/dotfiles` and
  `~/personal/*` it is the personal one; commits are signed.
- `ssh -T git@github.com` (personal key) and GitHub Enterprise (work key).
- `kitty`, `code`, `obsidian`, `neovide` start (Intel GPU); for NVIDIA:
  `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo -B`
  via `nix shell nixpkgs#mesa-demos`.
- Corporate tools (Zscaler, Intune, Edge, Teams) behave as before.

## Everyday use afterwards

```sh
nh home switch            # apply changes to nix/
nh home switch --update   # update all packages (flake.lock)
theme                     # theme picker (kitty, tmux, Neovim, CLI tools)
```

When apt upgrades the NVIDIA driver, `nh home switch` warns; update
`my.gpu.nvidia.version` and `sha256` in `nix/homes/work-laptop.nix` (the
warning says how).

## Rollback

```sh
~/dotfiles/scripts/rollback-to-chezmoi.sh
```

Removes the Home Manager generation and restores the backed-up chezmoi files
and binaries. Nix stays installed (uninstall: see the Nix manual).

## Later (after you sign off)

- remove duplicate apt/snap/flatpak installs and their apt repositories
  (Ansible cleanup task; corporate and OS packages are never touched)
- slim down Ansible to the Ubuntu system layer, retire chezmoi and the
  Bitwarden secrets role, update the top-level README and `install`
