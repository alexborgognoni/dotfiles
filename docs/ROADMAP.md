# Roadmap

## Next

- **Refactor and simplify**: done for Hyprland (`desktop/hyprland/`: binds,
  rules, animations, monitors, session, settings panel; the helper scripts are
  `.sh` files), the system-manager layer (one file per concern) and the
  corporate pieces (`modules/home/corporate/`, `system-manager/corporate.nix`).
  Noctalia too (`desktop/noctalia/`: package, bar, plugins and their catalog).
  The theme engine too (`modules/home/theme/`: options and activation, the
  `theme` command as `.sh`/`.py` files; `themes/`: defaults, accents,
  wallpapers, pack generator, the catalogue of themes).
  Identity too (`modules/home/identity/`: git, ssh, gpg; the work identity is
  `corporate/identity.nix`). `standalone/` too (integration, GPU, audio, secrets).
- **Ansible**: it only applies a package list, repositories, groups and the
  login shell. Decide whether a plain list and a short script replace it
  (one dependency less, less to explain to a coworker).
- **Hyprland Settings**: a helper that turns a kept change (display layout)
  into a snippet for `nix/homes/<machine>.nix`, so nothing stays imperative.
- **Optional text scale**: one setting multiplying all font sizes, on top of
  the screen scale.
- **Plugins**: re-pin the Noctalia plugins to their newest revisions once the
  packaged Noctalia supports plugin API 43.

## Machines

- **Home PC** (NixOS): add `nix/hosts/<host>`, reuse the same modules.
- **A coworker's Ubuntu laptop**: a `nix/homes/<name>.nix` and
  `nix/systems/<name>.nix`; `scripts/cleanup.d/` for their corporate agents.
  Test on a fresh 24.04 VM as well as 22.04.
