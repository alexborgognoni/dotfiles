# Nix configuration

One flake for every machine:

- **NixOS** (`nixosConfigurations`): the VM, later the home PC. Hyprland
  desktop with the Noctalia shell and live theme switching.
- **Ubuntu** (`homeConfigurations` + `systemConfigs`): the work laptop keeps
  Ubuntu for the OS, drivers and corporate software. Standalone Home Manager
  owns the user level (including GNOME settings and an extra "Hyprland (Nix)"
  session), [system-manager](https://github.com/numtide/system-manager) the
  root level, and a slim `../ansible/ubuntu.yml` the apt packages. One
  command sets it all up: `../install` (see
  [../docs/UBUNTU-MIGRATION.md](../docs/UBUNTU-MIGRATION.md)).

Both use the same Home Manager modules: zsh, starship, kitty, tmux, git/ssh/gpg,
Neovim (AstroNvim, plugins built by Nix), CLI tools and the theme engine.

Everything is pinned in `flake.lock`; nothing installs itself at runtime
(no lazy.nvim, Mason, tpm or zinit).

## Layout

```
flake.nix                 inputs, nixosConfigurations, homeConfigurations,
                          systemConfigs, packages, checks
hosts/<host>/             NixOS machines (vm)
homes/<machine>.nix       standalone Home Manager machines (work-laptop)
systems/<machine>.nix     system-manager (root level) of those machines
modules/
  nixos/                  NixOS only: nix settings, corporate CA, secrets,
                          locale, users, networking, desktop (Hyprland/UWSM,
                          greetd+ReGreet, PipeWire, Bluetooth, power, fonts,
                          keyd, Docker, libvirt), theme catalogue + Stylix,
                          Home Manager glue
  home/                   Home Manager, usable with and without NixOS (never
                          reads osConfig): theme engine, identity, shell,
                          terminal, editor, desktop, Firefox, fonts, packages,
                          standalone (generic Linux, GPU, nh, user secrets,
                          sound server), gnome (Ubuntu's GNOME)
  system-manager/         Ubuntu root level: nix.conf, keyd, GPU drivers,
                          Hyprland session + portal, lock-screen helper
  shared/                 plain data used by several module sets (keyd)
packages/default.nix      package groups: cli, gui, browsers
themes/default.nix        theme catalogue (colors, accents, wallpapers, look)
assets/wallpapers/        shared wallpapers (+ themes/<theme>/ for extras)
pkgs/                     packages not in nixpkgs (forgecode, openwhispr) and
                          the `pkgs.unstable` overlay
secrets/                  sops-encrypted: vm.yaml (host), personal.yaml and
                          work.yaml (SSH/GPG keys)
checks/default.nix        `nix flake check`
```

### Feature groups (Home Manager)

| Option | Contents | NixOS | Ubuntu laptop |
| --- | --- | --- | --- |
| always | shell, git/ssh/gpg, tmux, Neovim (AstroNvim), CLI tools, theme engine | yes | yes |
| `my.features.gui.enable` | kitty, Firefox, fonts | yes | yes |
| `my.features.desktop.enable` | Hyprland, Noctalia, desktop apps, GTK/Qt theming | yes | not yet |

`my.standalone = true` enables the non-NixOS integration: generic Linux paths
(GNOME app grid), GPU drivers for Nix GUI apps (`my.gpu.nvidia.version` must
match the host driver; `nh home switch` warns when it doesn't), `nh`, and
user-level sops decryption with the admin key.

## Everyday commands

```sh
nh os switch              # NixOS: rebuild and switch
nh home switch            # Ubuntu laptop: apply the Home Manager config
nh os|home switch --update   # update flake.lock first
nh clean all              # garbage-collect old generations
nix flake check           # all checks (needs ~16 GB RAM; see Checks)
```

Without `nh`: `sudo nixos-rebuild switch --flake ~/dotfiles/nix#<host>` or
`home-manager switch --flake ~/dotfiles/nix#alex@work-laptop`.

## Packages

Applications and tools come from **nixos-unstable** (`pkgs.unstable`, latest
versions); the base OS (kernel, systemd, Hyprland, greeter, drivers) stays on
the stable release. `--update` updates both. The groups live in
`packages/default.nix` (`cli`, `gui`, `browsers`): NixOS installs all of them
at the system level, a standalone machine picks groups with
`my.packages.groups` (the laptop leaves `browsers` to apt).

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
- Identity keys: `personal.yaml` (every machine) and `work.yaml` (only the
  work laptop, i.e. the admin key) hold the SSH and GPG private keys. NixOS
  decrypts them at boot, standalone Home Manager at activation; they end up as
  `~/.ssh/id_ed25519*` (owner-only) and in the GPG keyring, and commits are
  signed with the profile's key.
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
theme wallpaper next      # next wallpaper of the current theme
theme wallpaper rotate on|off|toggle   # automatic rotation
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
`defaultWallpaper`) is the default. The wallpaper panel opens the picker for the current
theme's library; rotation defaults are set with `my.wallpaper.rotation`.

## Keybindings (Hyprland)

| Keys | Action |
| --- | --- |
| Super + Return | kitty (attaches to the `main` tmux session) |
| Super + D | launcher |
| Super + Shift + Return | default browser |
| Super + E | file manager |
| Super + Shift + Q | close window |
| Super + M | exit Hyprland |
| Super + V / F / P | toggle floating / fullscreen / pseudotile |
| Super + O | toggle split |
| Super + Space | switch keyboard layout (all keyboards, also on the lock screen) |
| Super + h j k l (or arrows) | focus; + Shift move window |
| Super + 1..0 | workspace; + Shift move window there |
| Super + S / Shift+S | special workspace / move window there |
| Super + Shift + V | clipboard history |
| Super + T / Shift+T | theme picker / accent picker |
| Super + Escape / Shift+Escape | lock screen / session menu (log out, power) |
| Print / Shift+Print / Super+Print | screenshot region / screen / window (to ~/Pictures/Screenshots and the clipboard) |

## Checks

`nix flake check` builds every host and runs:

- `hyprland-config`: the generated `hyprland.lua` and every theme pack pass
  `Hyprland --verify-config`
- `theme-packs`: every theme x accent pack is complete and consistent
- `home-alex-work-laptop`: the standalone Home Manager configuration builds
- `system-work-laptop`: the system-manager configuration builds
- `vm`: boots the desktop configuration in a VM and tests theme switching,
  accents (validation and per-theme memory), persistence across re-activation,
  preview, zsh, Neovim, tmux, that every application/tool is installed and
  runs, and that Docker and keyd are up

`nix flake check` evaluates everything in one process (~20 GB peak); with
less RAM build the checks one by one:
`nix build .#checks.x86_64-linux.<name>`.

`../scripts/test-ubuntu-hm.sh` proves the Ubuntu laptop setup in a Ubuntu
22.04 container: it reproduces the current chezmoi state, migrates, verifies
shell, identities, keys, Neovim, tmux, themes, packages and GPU pieces, and
rolls back (needs Docker and the admin key; nothing on the host changes).
`../tests/ubuntu-vm/create.sh` creates a fresh Ubuntu 22.04 GNOME VM (HWE
kernel, NetworkManager, like the laptop) for testing `../install` end to end;
`../tests/ubuntu-vm/verify.sh` then asserts the result (system layer, GDM,
network, audio, Hyprland session, portals, lock screen PAM, GNOME, identity).

Fewer pre-built themes: `my.themes.prebuilt = [ "nord" ... ]` (Home Manager)
limits the specialisations (faster rebuilds, less memory); `theme list` then
only offers those.

## Adding a host

1. Install NixOS, then copy `/etc/nixos/hardware-configuration.nix` to
   `hosts/<name>/`.
2. Create `hosts/<name>/default.nix` (see `hosts/vm`), with that machine's boot
   loader, `networking.hostName`, monitors, `my.corporateCA` if it sits behind
   TLS inspection, and `system.stateVersion`.
3. Add it to `nixosConfigurations` in `flake.nix` and switch with
   `sudo nixos-rebuild switch --flake ~/dotfiles/nix#<name>`.

## Adding a standalone (non-NixOS) machine

1. Create `homes/<machine>.nix` (see `homes/work-laptop.nix`): username,
   `my.standalone = true`, profile, features, package groups, GPU.
2. Create `systems/<machine>.nix` (see `systems/work-laptop.nix`).
3. Add both to `homeConfigurations` and `systemConfigs` in `flake.nix`.
4. On the machine: `../install <machine>` (Ubuntu).

## Notes

- Flakes only see files tracked by git: `git add` new files before building.
- Noctalia settings changed in its GUI are saved to
  `~/.local/state/noctalia/settings.toml` and override the Nix defaults.
- Layouts: several `my.keyboard.layout` entries switch with Super+Space (all
  keyboards at once). Do not use `grp:` options in `my.keyboard.options`:
  Hyprland keeps the layout per keyboard device.
- Noctalia panels opened from the bar are floating and solid (an attached
  panel inherits the transparent bar's opacity). Plugin panels need the same
  per plugin: `plugin_settings."<id>".<panel id>_placement = "floating"`.
- `my.desktop.airpods.enable`: AirPods in the bar (Noctalia plugin
  `harveywuk/airpods` and the patched librepods daemon as a user service).
- `my.desktop.noctalia.plugins`: pinned Noctalia plugins (bitwarden,
  screen_recorder, file-search, keybind-cheatsheet, nvtop, pomodoro, airpods)
  with their tools. Panel placement keys are `<panel id>_placement` and so on.
- kitty's shell integration has no `sudo` wrapper: it runs `sudo TERMINFO=...`,
  which the sudoers allow-list refuses.
- The `work` profile sets the work git identity (with personal identity under
  `~/personal` and `~/dotfiles`), the work GitHub Enterprise SSH host, and CA
  variables for Node/Python.
- `my.corporateCA` also passes the CA into the Nix build sandbox, so source
  fetches work behind Zscaler.
