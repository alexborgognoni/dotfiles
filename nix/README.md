# Nix configuration

One flake for every machine:

- **NixOS** (`nixosConfigurations`): the VM, later the home PC. Hyprland
  desktop with the Noctalia shell and live theme switching.
- **Ubuntu** (`homeConfigurations` + `systemConfigs`): the work laptop keeps
  Ubuntu for the OS, drivers and corporate software. Standalone Home Manager
  owns the user level (including GNOME settings and an extra "Hyprland (Nix)"
  session), [system-manager](https://github.com/numtide/system-manager) the
  root level, and a short script with plain lists (`../apt/`) the apt packages. One
  command sets it all up: `../install` (see
  [../docs/UBUNTU.md](../docs/UBUNTU.md)).

Both use the same Home Manager modules: zsh, starship, kitty, tmux, git/ssh/gpg,
Neovim (AstroNvim, plugins built by Nix), CLI tools and the theme engine.

Everything is pinned in `flake.lock`; nothing installs itself at runtime
(no lazy.nvim, Mason, tpm or zinit).

## Neovim (AstroNvim)

Neovim, the plugins and the tools come from nixpkgs-unstable and are updated
with everything else: `nh home switch --update`. AstroNvim's `:AstroUpdate` and
lazy.nvim's update keys (`<Leader>pi/pS/pu/pU/pa`) only say so; the plugin
directory is read-only.

- **A language** (server, formatter, linter) is one entry in
  `modules/home/editor/astronvim/languages.nix`: the package and the name the
  plugin knows it by. The build checks the names against nvim-lspconfig and
  none-ls, so a typo fails the build, not Neovim. One formatter per language
  (a server that formats well, like gopls, does it itself).
- **A plugin**: its spec in `config/lua/plugins/`, and one line in the
  `plugins` table of `default.nix` (repository name = nixpkgs vim plugin;
  `vimUtils.buildVimPlugin` with a pinned revision if nixpkgs has none).
- **A tool for one project**: `nix develop` or direnv puts it first on `PATH`;
  to try one now, `nix shell nixpkgs#gopls -c nvim`.

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
                          sound server), gnome (Ubuntu's GNOME), corporate
                          (Zscaler tray, Entra SSO, Artifactory, company tools)
  system-manager/         Ubuntu root level, one file per concern: nix.conf,
                          keyd, tweaks, GPU drivers, Hyprland session + portal
                          + lock-screen helper, corporate
  shared/                 plain data used by several module sets (keyd)
packages/default.nix      package groups: cli, gui, browsers
themes/                   theme catalogue: catalogue.nix (the themes), defaults,
                          accents, wallpapers, pack.nix (live color files)
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
| `my.features.desktop.enable` | Hyprland, Noctalia, desktop apps, GTK/Qt theming | yes | yes (a session next to GNOME) |

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
nix fmt                   # format the whole repository (from nix/)
nix run path:nix#lint     # format check + linters (from anywhere in the repo)
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
- Docker, libvirt/virt-manager and keyd (Caps Lock = Escape) are system
  modules in `modules/nixos/desktop/`. Alt+hjkl as arrow keys is only for the
  corporate laptop (below).

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
  decrypts the personal ones at boot, standalone Home Manager at activation
  (the work ones too, through the corporate module); they end up as
  `~/.ssh/id_ed25519*` (owner-only) and in the GPG keyring, and commits are
  signed with the profile's key. Which secret belongs where is one table,
  `modules/shared/identity-secrets.nix`: a new one is a row there and a value
  in its sops file.
- `tests/scripts/run.sh secrets` checks that every sops file is encrypted, that
  only keys declared in `.sops.yaml` can decrypt them (the work file: the admin
  key only), and that no private key or token is in git.
- With `my.secrets.enable`, users are declarative (`mutableUsers = false`):
  the login password is the `<user>-password` secret; `passwd` has no effect.
- New machine: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`, add the key
  and a creation rule to `.sops.yaml`, then `sops updatekeys` / create its
  secrets file.

## Themes

A theme is a complete look: base16 colors, an accent palette, a wallpaper
library, fonts, cursor, icons, opacity and window decoration (rounding,
borders, gaps, shadow, blur). `themes/defaults.nix` has the shared defaults;
`themes/catalogue.nix` lists the themes, each overriding only what differs (add
a theme there: a name from nixpkgs' base16-schemes is enough). The rest of
`themes/` is machinery: accents, wallpapers, and `pack.nix`, which generates
the color files below.

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

## Corporate

Everything that only makes sense on a company laptop is separate, so a
personal machine never gets it and a coworker can swap it for their own:

| Layer | Module | Switched on by | Contents |
|---|---|---|---|
| user (Home Manager) | `modules/home/corporate/` | `my.corporate.enable`, default: `my.profile == "work"` | Zscaler tray (unit, launcher, `zsa://` links), Entra ID SSO for Chrome and Firefox, the work identity (git email, GPG/SSH keys, GitHub Enterprise: `my.identity.work`), pip through Artifactory, `fix-zscaler`/`net-diag`/`net-rescue`, Claude Code against the company's Vertex AI and Copilot |
| root (system-manager) | `modules/system-manager/corporate.nix` | `my.corporate.enable = true` in `systems/<machine>.nix` | corporate root CA for the Nix daemon and for Chrome, Alt+hjkl as arrow keys (keyd) |
| NixOS | `modules/nixos/core/corporate-ca.nix` | `my.corporateCA = [ ./root.crt ]` | extra root CAs, also in the build sandbox |

Machine-specific values of the laptop (Docker's network, NTP servers) are in
`systems/work-laptop.nix` and `homes/work-laptop.nix`. The apt side
(Zscaler's Qt libraries, Edge) is `../apt/packages.list`.

## Checks

`nix flake check` builds every host and runs:

- `hyprland-config`: the generated `hyprland.lua` and every theme pack pass
  `Hyprland --verify-config`
- `theme-packs`: every theme x accent pack is complete and consistent
- `home-alex-work-laptop`: the standalone Home Manager configuration builds
- `system-work-laptop`: the system-manager configuration builds
- `lint-nix`: nixfmt, statix and deadnix on the flake (the repo-wide `lint`
  also covers shell and Lua)
- `vm`: boots the desktop configuration in a VM and tests theme switching,
  accents (validation and per-theme memory), persistence across re-activation,
  preview, zsh, Neovim, tmux, that every application/tool is installed and
  runs, and that Docker and keyd are up

`nix flake check` evaluates everything in one process (~20 GB peak); with
less RAM build the checks one by one:
`nix build .#checks.x86_64-linux.<name>`.

## Formatting and linting

`tooling.nix` defines both, from the flake's pinned nixpkgs:

| What | Tool | Where it runs |
|---|---|---|
| Nix formatting | nixfmt | `nix fmt` |
| shell formatting (2 spaces) | shfmt | `nix fmt` |
| Lua formatting | stylua, with AstroNvim's `.stylua.toml` | `nix fmt` |
| Nix lint | statix (`statix.toml` turns off "repeated keys"), deadnix | `lint`, `lint-nix` |
| shell lint | shellcheck (warnings and up, all scripts incl. the Nix-embedded `.sh` files) | `lint` |
| Lua lint | selene (AstroNvim's `selene.toml`) | `lint` |

`nix fmt` rewrites files; `nix run path:nix#lint` never does (it formats a copy
and shows the diff) and exits non-zero on any finding, so it can sit in a
pre-commit hook or CI. Generated files (`hosts/vm/hardware-configuration.nix`)
are skipped. `.editorconfig` tells editors the same indentation.

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
  file-search, keybind-cheatsheet, nvtop, pomodoro, airpods)
  with their tools. Panel placement keys are `<panel id>_placement` and so on.
- kitty's shell integration has no `sudo` wrapper: it runs `sudo TERMINFO=...`,
  which the sudoers allow-list refuses.
- The `work` profile turns on the corporate module, which sets the work git
  identity (with personal identity under `~/personal` and `~/dotfiles`) and the
  work GitHub Enterprise SSH host (`modules/home/corporate/identity.nix`).
- `my.corporateCA` also passes the CA into the Nix build sandbox, so source
  fetches work behind Zscaler.
