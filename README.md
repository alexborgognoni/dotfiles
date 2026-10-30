# Dotfiles

One [Nix](https://nixos.org) flake for every machine, Nix only (no chezmoi,
no per-tool installers):

- **Ubuntu work laptop**: Ubuntu keeps the OS, drivers and corporate software;
  Nix (Home Manager + [system-manager](https://github.com/numtide/system-manager))
  owns everything else, including a Hyprland session next to GNOME. A slim
  Ansible playbook installs the few apt packages Nix cannot provide.
- **NixOS** (a VM, later a home PC): the same user-level modules.

The desktop is Hyprland with the Noctalia shell and a live theme engine
(`theme` switches kitty, tmux, Neovim, Hyprland, Noctalia, GTK/Qt at once).
Shell, Neovim (AstroNvim, plugins built by Nix), git/ssh/gpg identities,
secrets (sops) and all tools come from the same pinned modules.

## Ubuntu: one command

Needs Ubuntu 22.04+, sudo, and the sops admin key (Bitwarden item
`sops-age-key`, or the `SOPS_AGE_KEY` variable, or pasted when asked).

```sh
curl -fsSL https://raw.githubusercontent.com/alexborgognoni/dotfiles/nixos/install | DOTFILES_BRANCH=nixos bash
# or from a clone:  ~/dotfiles/install [machine]      (default: work-laptop)
```

Idempotent; asks for sudo once. It installs Nix, takes a one-time snapshot of
the current system, installs the apt packages, then applies the system layer
and the user layer. Log out and back in afterwards. Details, checks and
rollback: [docs/UBUNTU.md](docs/UBUNTU.md).

Everyday:

```sh
nh home switch                                       # user level
sudo system-manager switch --flake ~/dotfiles/nix#work-laptop   # system level
nh home switch --update                              # update everything (flake.lock)
```

## Layout

```
install            Ubuntu entry point (all layers)
nix/               the flake: hosts, homes, modules, themes, secrets   -> nix/README.md
ansible/ubuntu.yml the apt packages Nix cannot provide on Ubuntu
scripts/           Nix bootstrap, snapshot, optional cleanup           -> scripts/README.md
tests/ubuntu-vm/   fresh Ubuntu VM: create it, run ./install, verify
tests/scripts/     tests for the scripts: tests/scripts/run.sh
docs/              runbook, plan, roadmap
```

## Documentation

- [nix/README.md](nix/README.md): modules, features, themes, secrets, everyday commands, tests
- [docs/UBUNTU.md](docs/UBUNTU.md): the Ubuntu runbook and Hyprland session notes
- [scripts/README.md](scripts/README.md): the scripts, and how to adapt the cleanup (protect lists) to another machine
- [docs/ROADMAP.md](docs/ROADMAP.md): what is next
- [docs/NIX-PLAN.md](docs/NIX-PLAN.md): the migration plan (historical record)

The earlier chezmoi + Ansible setup is kept at the git tag
`legacy-chezmoi-ansible`.
