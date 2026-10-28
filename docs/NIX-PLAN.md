# Nix migration plan (spec for sign-off)

Status: **approved; phases 0-2 done, phase 3 ready to apply**
([UBUNTU-MIGRATION.md](UBUNTU-MIGRATION.md))
Scope: this repository (`~/dotfiles`)

## 1. Context

- **Work laptop** (Ubuntu 22.04, GNOME, Intel + NVIDIA RTX A2000 on driver
  595.84 in PRIME on-demand mode, behind Zscaler). It **stays on Ubuntu**
  permanently: the corporate software (Zscaler, CrowdStrike, Intune, Citrix,
  Micro Focus, Cisco) cannot run on NixOS and NixOS is not approved there.
- **NixOS VM** on the work laptop (QEMU/KVM, libvirt). Used to develop the
  NixOS setup, and as a NixOS environment in its own right.
- **Home PC** (NVIDIA): the eventual NixOS dual-boot target. Out of scope
  until its questions are resolved (see section 9).
- The NixOS configuration built so far lives in `nixos/` (Hyprland, Noctalia,
  Stylix theme engine with live preview, accents and wallpaper libraries,
  nixvim, sops-nix, packages from nixos-unstable, flake checks including a
  NixOS VM test). It currently works and is verified in the VM.

## 2. Goals

1. **One source of truth** for user-level configuration and tooling across
   all machines: Nix + Home Manager on NixOS *and* on Ubuntu.
2. **Nix for everything user-level** on Ubuntu (CLI tools, dev toolchains,
   editors, GUI apps, fonts); apt only for what must be system-level.
3. Keep the work laptop fully functional and compliant at every step, with a
   fallback (chezmoi) until the migration is signed off.
4. Make the VM a comfortable daily NixOS environment.
5. Everything declarative, pinned (`flake.lock`), tested (`nix flake check`
   plus a Ubuntu container test), and documented.

## 3. Non-goals

- Replacing Ubuntu's OS layer, drivers, GNOME session or corporate software.
- Running corporate software on NixOS.
- The home PC configuration (separate phase, after its questions).
- Hyprland on Ubuntu in the first phases (planned for phase 5).

## 4. Decisions

| Topic | Decision |
| --- | --- |
| Configs on Ubuntu | Nix + standalone Home Manager; chezmoi retired after sign-off |
| Package source on Ubuntu | Nix for all user-level software; apt only for the "must stay" list (section 6.4) |
| GPU for Nix GUI apps on Ubuntu | Home Manager `targets.genericLinux.gpu` (Mesa for Intel; NVIDIA libraries pinned to the host driver version) |
| Package versions | Applications/tools from nixos-unstable; base OS (NixOS) on the stable release |
| Profiles | Work laptop: `work`. VM and home PC: `personal` |
| VM editing workflow | Edit on Ubuntu, `~/dotfiles` shared into the VM via virtiofs |
| SSH/GPG private keys | Encrypted in the repo with sops-nix, per machine/profile |
| System-level config on Ubuntu | Small Ansible playbook (system-manager may be evaluated later) |
| Hyprland on Ubuntu | Later phase (5), with GNOME kept as a fallback session |

## 5. Target architecture

### 5.1 Repository layout

```
dotfiles/
├── nix/                    # renamed from nixos/: one flake for all machines
│   ├── flake.nix           # nixosConfigurations (vm, home-pc later),
│   │                       # homeConfigurations ("alex@work-laptop"), checks
│   ├── hosts/              # per-machine NixOS configs
│   ├── homes/              # per-machine standalone Home Manager configs
│   ├── modules/nixos/      # NixOS-only modules
│   ├── modules/home/       # Home Manager modules, usable with and without NixOS
│   ├── themes/  pkgs/  secrets/  assets/  checks/
├── ansible/                # Ubuntu-only system layer (slimmed down)
├── chezmoi/                # kept as fallback until sign-off, then removed
├── scripts/                # incl. test-ubuntu-hm.sh (container test)
├── docs/
└── install                 # bootstraps Nix + Home Manager (+ Ansible) on Ubuntu
```

### 5.2 Home Manager modules work standalone

Home Manager modules must not depend on `osConfig`. Today they read the theme
catalogue, monitors, keyboard layout and the Hyprland package from NixOS;
these become Home Manager options (the theme catalogue is built inside Home
Manager). NixOS forwards system values when present.

### 5.3 Feature groups

| Group | Contents | VM / home PC | Work laptop |
| --- | --- | --- | --- |
| `core` | shell (zsh, starship, CLI tools), git/ssh/gh, tmux, nixvim, theme engine for terminal apps, CLI packages | yes | yes |
| `gui` | kitty, Neovide, Firefox, GUI applications, fonts | yes | yes (via GPU module) |
| `desktop` | Hyprland, Noctalia, desktop theme switching | yes | phase 5 |

### 5.4 Package groups

- `cli`: from Nix everywhere.
- `gui-apps`: from Nix; on Ubuntu, per-app choice of Nix or apt where vendor
  packaging integrates better.
- Corporate and OS packages: apt (Ubuntu only).

## 6. Requirements

### 6.1 Shared (all machines)

- R1. User configs (zsh, starship, kitty, tmux, nixvim, git, ssh, gh, bat,
  fzf, eza, zoxide, yazi, btop, lazygit, fastfetch) come from the same Home
  Manager modules on NixOS and Ubuntu.
- R2. The theme engine (`theme` command: pick, preview, apply, accents,
  wallpapers) works for kitty, tmux and Neovim on all machines; desktop parts
  (Hyprland, Noctalia) only where `desktop` is enabled.
- R3. Identities follow the profile: work email by default on the work laptop
  with personal identity under `~/personal` and `~/dotfiles`; personal
  everywhere else.
- R4. SSH and GPG private keys are deployed from sops secrets with correct
  permissions; work keys only to work-profile machines, personal keys to all.
- R5. All flake inputs pinned; `nix flake check` passes.

### 6.2 NixOS (VM, home PC)

- R6. Everything that exists today keeps working (verified by the existing VM
  test and live theme suite).
- R7. VM: personal profile; user UID 1001 matching the host; `~/dotfiles`
  shared via virtiofs so rebuilds read the host checkout directly.
- R8. VM: optional per-host subset of pre-built themes for faster rebuilds.
- R9. VM: recreatable from a script in the repo (firmware without Secure
  Boot, user-mode networking for Zscaler, host-only network for SSH).

### 6.3 Ubuntu work laptop

- R10. Nix installed (multi-user daemon) with the Zscaler CA configured for
  the daemon and the build sandbox.
- R11. Standalone Home Manager configuration `alex@work-laptop` with `core`
  and `gui`, profile `work`.
- R12. GPU integration via `targets.genericLinux.gpu` with NVIDIA 595.84
  pinned; the rebuild command warns when the host driver version differs.
- R13. Nix GUI apps appear in GNOME's app grid (`targets.genericLinux`).
- R14. GNOME settings currently in the Ansible `gnome` role move to Home
  Manager `dconf` where possible.
- R15. After the Nix versions are verified, duplicate apt/snap/flatpak
  installs and their apt repositories are removed by an Ansible cleanup task
  that never touches corporate or OS packages.
- R16. chezmoi remains usable as a fallback until sign-off, then is removed
  (including the stray nested `chezmoi/.git`).

### 6.4 Stays on apt (Ubuntu)

Base OS (kernel, GRUB, systemd, glibc, NetworkManager, PipeWire, CUPS,
Bluetooth, firmware, sudo, polkit), GNOME/GDM and extensions, kernel drivers
(NVIDIA 595, Realtek r8125), corporate agents (Zscaler, CrowdStrike, Intune +
identity broker, Citrix, Micro Focus, Cisco), browsers used for company
sign-in (Edge, and Chrome if used for work), root system services (Docker
engine, libvirt/QEMU, keyd, database servers).

### 6.5 Ansible (slimmed)

- R17. Ansible keeps only the Ubuntu system layer: apt repositories and
  packages from 6.4, Docker/libvirt/keyd configuration, the one-time GPU
  setup, Nix daemon configuration, and (phase 5) the Hyprland session files.
- R18. The Bitwarden-based secrets role is retired in favour of sops.

### 6.6 Testing and documentation

- R19. `scripts/test-ubuntu-hm.sh`: Ubuntu 22.04 container with Nix and the
  Zscaler CA builds and activates `alex@work-laptop` and verifies zsh, tmux,
  Neovim, git identity and the terminal theme engine. Replaces
  `scripts/test-docker.sh`.
- R20. `nix flake check` builds `homeConfigurations."alex@work-laptop"` and
  all NixOS hosts, and runs the existing checks.
- R21. Top-level README and docs describe both worlds (NixOS and Ubuntu) and
  the everyday commands for each.

## 7. Phases and acceptance criteria

### Phase 0: safety net
- All current work committed and pushed to a new branch.
- **Done when:** the branch exists on GitHub.

### Phase 1: refactor (no behaviour change on NixOS)
- Rename `nixos/` to `nix/`; Home Manager modules made standalone (5.2);
  feature groups (5.3); package groups (5.4); profiles (VM becomes personal);
  sops recipients per machine/profile; SSH/GPG keys as secrets (R4).
- **Done when:** the VM rebuilds, `nix flake check` passes, the live theme
  suite passes, keys are deployed in the VM with correct permissions, and the
  VM uses the personal identity.

### Phase 2: prove it in a container
- Container test (R19) passes for `alex@work-laptop`.
- **Done when:** the script passes from a clean container.

### Phase 3: work laptop migration
- You run the Nix install command (requires sudo). Then: Zscaler CA (R10),
  activate Home Manager with chezmoi kept as fallback (R11, R16), GPU module
  and driver check (R12), GNOME app grid (R13), dconf (R14), slim Ansible
  (R17, R18), docs (R21).
- Cleanup of duplicate apt/snap/flatpak packages (R15) only after you
  confirm everything works.
- **Done when:** daily tools come from Nix, GUI apps run (Intel and NVIDIA
  offload), no corporate package was touched, and you sign off.

### Phase 4: VM improvements
- Personal profile, UID 1001 + virtiofs (R7), theme subset (R8), recreate
  script (R9); with Nix on the host, try a modern QEMU from nixpkgs for
  working 3D acceleration in the VM.
- **Done when:** editing on Ubuntu and rebuilding in the VM needs no sync
  step, and the VM can be recreated from the script.

### Phase 5: Hyprland on Ubuntu (later)
- Hyprland + Noctalia + desktop theme switching on Ubuntu with GNOME kept as
  fallback: GDM session file, PAM configuration for the lock screen, portals.
- **Done when:** a Hyprland session works on the work laptop alongside GNOME.

### Phase 6: home PC (later)
- After the questions in section 9 are answered.

## 8. Risks

| Risk | Mitigation |
| --- | --- |
| Company policy on Nix (root daemon) and EDR reactions | Your decision before phase 3; Nix is removable |
| NVIDIA driver updates via apt break pinned Nix libraries | Version check in the rebuild command; Intel-rendered apps unaffected |
| nixos-unstable packages break | Per-package fallback to stable with a comment (as with azure-cli, semgrep) |
| Losing the sops admin key | Copies on laptop and VM; must also be stored in Bitwarden |
| Migration breaks the daily setup | chezmoi fallback until sign-off; Home Manager generations allow rollback |

## 9. Open items

- Home PC: hardware details and your open questions (before phase 6).
- Back up `~/.config/sops/age/keys.txt` in Bitwarden.
- Company approval for installing Nix on the work laptop (before phase 3).

## 10. Progress

- Phase 0: branch `nixos` pushed.
- Phase 1: `nix/` with shared Home Manager modules, feature and package
  groups, standalone module, `alex@work-laptop`, identity keys in sops
  (`secrets/personal.yaml`, `secrets/work.yaml`), VM on the personal profile,
  `my.themes.prebuilt` (R8). Verified: VM rebuild, all flake checks, live
  theme suite (195/195), signed commits and GitHub SSH in the VM.
- Phase 2: `scripts/test-ubuntu-hm.sh` passes 50/50 (chezmoi state ->
  migration -> verification -> second activation -> rollback).
  `scripts/bootstrap-nix.sh`, `migrate-to-home-manager.sh` and
  `rollback-to-chezmoi.sh` are ready for the laptop.
- Not covered by the container (needs the real laptop): the multi-user Nix
  daemon setup, the GPU setup with the real NVIDIA driver, GNOME app grid
  after re-login.

## 11. Sign-off

- [x] Plan approved
- [ ] Phase 1 accepted
- [ ] Phase 2 accepted
- [ ] Phase 3 accepted
- [ ] Phase 4 accepted
