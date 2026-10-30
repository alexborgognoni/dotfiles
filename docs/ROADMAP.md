# Roadmap

## Next

- **Refactor and simplify**: the large modules (`hyprland.nix`, `noctalia.nix`)
  and the small helper scripts embedded in them (`monitor-roles`, `toggle-bar`,
  `wait-session`) should become modules of their own; remove what is unused.
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
