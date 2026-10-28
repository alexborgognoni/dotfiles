# NixOS configuration

Fully declarative NixOS + Home Manager flake: Hyprland desktop with the
Noctalia shell, live theme switching (themes, accents, wallpapers), and the
programs from `../chezmoi` (zsh, starship, kitty, tmux, git, Neovim) ported to
Nix.

Everything is pinned in `flake.lock`; nothing installs itself at runtime
(no lazy.nvim, Mason, tpm or zinit).

## Layout

```
flake.nix                 inputs, hosts (mkHost), checks
hosts/
  vm/                     QEMU/KVM test VM (hardware config, Zscaler CA, SSH)
modules/
  nixos/                  system: nix settings, corporate CA, locale, users,
                          networking, desktop (Hyprland/UWSM, greetd+ReGreet,
                          PipeWire, Bluetooth, power, fonts), theme catalogue
                          + Stylix, Home Manager glue
  home/                   user: theme engine, identity (git/ssh/gh), shell,
                          terminal (kitty, tmux), editor (nixvim), desktop
                          (Hyprland, Noctalia, apps), Firefox
home/default.nix          the user's Home Manager entry point
themes/default.nix        theme catalogue (colors, accents, wallpapers, look)
assets/wallpapers/        shared wallpapers (+ themes/<theme>/ for extras)
pkgs/                     packages not in nixpkgs (forgecode, openwhispr) and
                          the `pkgs.unstable` overlay
secrets/<host>.yaml       sops-encrypted secrets (see .sops.yaml)
checks/default.nix        `nix flake check`
```

## Everyday commands

```sh
nh os switch              # rebuild and switch (flake path is preconfigured)
nh os switch --update     # update flake.lock first
nh clean all              # garbage-collect old generations
nix flake check           # run all checks, including the VM test
```

Without `nh`: `sudo nixos-rebuild switch --flake ~/dotfiles/nixos#<host>`.

## Packages

Applications and tools come from **nixos-unstable** (`pkgs.unstable`, latest
versions); the base OS (kernel, systemd, Hyprland, greeter, drivers) stays on
the stable release. `nh os switch --update` updates both. The list lives in
`modules/nixos/packages.nix`, grouped by purpose (installed for the user
at the NixOS level, so it is evaluated once rather than once per theme).

- If something is broken in unstable, take it from stable temporarily
  (`pkgs.<name>` instead of `u.<name>`) with a comment, as done for
  `azure-cli`.
- Packages that nixpkgs lacks are in `pkgs/`; update them with
  `nix run nixpkgs#nix-update -- --flake <name>` (or bump version and hash).
- Projects should bring their own toolchains (`nix develop`, direnv, uv):
  the global Python, Node, Rust (rustup) and Go are for quick work.
- Databases run per project in Docker; only the clients are installed.
- Docker, libvirt/virt-manager and keyd (Caps Lock = Escape, Alt+hjkl =
  arrows, everywhere) are system modules in `modules/nixos/desktop/`.

## Secrets (sops-nix)

Secrets are encrypted with age in `secrets/<host>.yaml`; `.sops.yaml` lists
who can decrypt them: your admin key (to edit) and each machine's SSH host
key (machines decrypt at boot, nothing to copy).

```sh
sops secrets/vm.yaml      # edit (needs ~/.config/sops/age/keys.txt)
mkpasswd -m yescrypt      # hash for <user>-password
```

- **Back up `~/.config/sops/age/keys.txt` (e.g. in Bitwarden).** Without it
  and without the machines' host keys, the secrets are gone.
- With `my.secrets.enable`, users are declarative (`mutableUsers = false`):
  the login password is the `<user>-password` secret; `passwd` has no effect.
- New machine: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`, add the key
  and a creation rule to `.sops.yaml`, then `sops updatekeys` / create its
  secrets file.

## Themes

A theme is a complete look: base16 colors, an accent palette, a wallpaper
library, fonts, cursor, icons, opacity and window decoration (rounding,
borders, gaps, shadow, blur). `themes/default.nix` has shared defaults; each
theme overrides only what differs.

```sh
theme                     # picker with live preview (Super+T)
theme apply nord          # switch theme
theme preview nord        # live-preview only
theme accent              # accent picker with live preview (Super+Shift+T)
theme accent peach        # set the accent of the current theme
theme accent list
theme wallpaper next      # next wallpaper of the current theme (Super+Shift+W)
theme wallpaper rotate on|off|toggle   # automatic rotation (Super+Ctrl+W)
theme list | current
```

How it works:

- Every theme x accent combination has a **pack** in the Nix store with
  ready-made colors for kitty, tmux, Neovim, Hyprland and Noctalia, plus the
  theme's wallpapers. Those programs read their colors through
  `~/.local/state/theme/current`; previewing re-points that link and reloads
  them (instant, also while moving through the picker).
- Applying a theme additionally activates its pre-built Home Manager
  specialisation, which re-themes everything else via Stylix (GTK, Qt,
  Firefox, fonts, cursor, icons, ...). Firefox and GTK apps pick it up when
  restarted.
- Your choice (theme, and the accent per theme) is kept in
  `~/.local/state/theme/` and survives rebuilds and reboots.

**Accents:** every theme offers its base16 accent colors, named by their
actual hue (`red`, `orange`, `yellow`, `lime`, `green`, `cyan`, `blue`,
`purple`, `pink`, with `light-`/`deep-` variants on clashes); Catppuccin themes
offer their 14 named colors instead. A theme sets its default with `accent`
and `accent2` (second stop of the border gradient).

**Wallpapers:** each theme has its own library: the shared images in
`assets/wallpapers/` (recolored to the palette unless `recolor = false`) plus
anything in `assets/wallpapers/themes/<theme>/`. The first one (or
`defaultWallpaper`) is the default. Super+W opens the picker for the current
theme's library; rotation defaults are set with `my.wallpaper.rotation`.

## Keybindings (Hyprland)

| Keys | Action |
| --- | --- |
| Super + Return | kitty (attaches to the `main` tmux session) |
| Super + Space | launcher |
| Super + S | control center (Wi-Fi, Bluetooth, audio, brightness, power) |
| Super + , | Noctalia settings |
| Super + V | clipboard history |
| Super + T / Shift+T | theme picker / accent picker |
| Super + W / Shift+W / Ctrl+W | wallpaper picker / next / toggle rotation |
| Super + Escape | session menu |
| Super + Ctrl + L | lock screen |
| Super + B / E | Firefox / file manager |
| Super + Q | close window |
| Super + F / Shift+F | fullscreen / toggle floating |
| Super + O / P | toggle split / pseudotile |
| Super + h j k l (or arrows) | focus; + Shift move; + Ctrl swap |
| Super + 1..0 | workspace; + Shift move window there |
| Super + \` / Shift+\` | scratchpad / move window to scratchpad |
| Print / Shift+Print / Super+Print | screenshot region / screen / window (to ~/Pictures/Screenshots and the clipboard) |
| Alt + Tab | window switcher |

## Checks

`nix flake check` builds every host and runs:

- `hyprland-config`: the generated `hyprland.lua` and every theme pack pass
  `Hyprland --verify-config`
- `theme-packs`: every theme x accent pack is complete and consistent
- `vm`: boots the desktop configuration in a VM and tests theme switching,
  accents (validation and per-theme memory), persistence across re-activation,
  preview, zsh, Neovim, tmux, that every application/tool is installed and
  runs, and that Docker and keyd are up

## Adding a host

1. Install NixOS, then copy `/etc/nixos/hardware-configuration.nix` to
   `hosts/<name>/`.
2. Create `hosts/<name>/default.nix` (see `hosts/vm`), with that machine's boot
   loader, `networking.hostName`, monitors, `my.corporateCA` if it sits behind
   TLS inspection, and `system.stateVersion`.
3. Add it to `nixosConfigurations` in `flake.nix` and switch with
   `sudo nixos-rebuild switch --flake ~/dotfiles/nixos#<name>`.

## Notes

- Flakes only see files tracked by git: `git add` new files before building.
- Noctalia settings changed in its GUI are saved to
  `~/.local/state/noctalia/settings.toml` and override the Nix defaults.
- The `work` profile sets the work git identity (with personal identity under
  `~/personal` and `~/dotfiles`), the work GitHub Enterprise SSH host, and CA
  variables for Node/Python.
- `my.corporateCA` also passes the CA into the Nix build sandbox, so source
  fetches work behind Zscaler.
