#!/usr/bin/env bash
# Runs inside the Ubuntu 22.04 container (scripts/test-ubuntu-hm.sh):
#   1. reproduce today's laptop state (chezmoi, work profile, stray binaries)
#   2. migrate to Home Manager (scripts/migrate-to-home-manager.sh)
#   3. verify shell, identities, keys, editor, tmux, themes, packages, GPU
#   4. activate again (idempotent), then roll back to chezmoi and verify
set -uo pipefail

dotfiles="$HOME/dotfiles"
config="alex@work-laptop"
pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { # description, command...
  local desc="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then ok "$desc"; else bad "$desc" "$(tail -3 <<<"$out")"; fi
}
section() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
# Run in a fresh interactive login zsh, like a new terminal.
inzsh() { zsh -lic "$1"; }

section "Reproduce the current laptop state"
PROFILE=work chezmoi init --source "$dotfiles/chezmoi" --apply --no-tty --force >/dev/null 2>&1 \
  && ok "chezmoi applied (work profile)" || bad "chezmoi apply"
check "old ~/.gitconfig present" test -f ~/.gitconfig
mkdir -p ~/.local/bin ~/.config/sops/age
printf '#!/bin/sh\necho stale-kitty\n' > ~/.local/bin/kitty
printf '#!/bin/sh\necho stale-uv\n' > ~/.local/bin/uv
printf '#!/bin/sh\necho mine\n' > ~/.local/bin/fix-zscaler
chmod +x ~/.local/bin/*
install -m 600 /run/agekey ~/.config/sops/age/keys.txt

section "Migrate to Home Manager"
if "$dotfiles/scripts/migrate-to-home-manager.sh" "$config" > /tmp/migrate.log 2>&1; then
  ok "migration script"
else
  bad "migration script" "$(tail -15 /tmp/migrate.log)"
  echo "PASS=$pass FAIL=$fail"
  exit 1
fi
# shellcheck disable=SC1091
. "$HOME/.nix-profile/etc/profile.d/nix.sh"

section "Shell"
out="$(zsh -lic exit 2>&1)"
[ -z "$out" ] && ok "zsh starts without output or errors" || bad "zsh starts cleanly" "$out"
check "aliases (ls = eza)" inzsh 'alias ls | grep -q eza'
check "fzf-tab loaded" inzsh 'whence fzf-tab-complete'
check "zoxide and starship initialised" inzsh 'whence z && whence starship_precmd || whence prompt_starship_precmd'
check "work CA variables" inzsh '[ "$NODE_EXTRA_CA_CERTS" = /etc/ssl/certs/ca-certificates.crt ]'
check "Nix tools win over stale ~/.local/bin" inzsh '[ "$(command -v kitty)" != "$HOME/.local/bin/kitty" ]'
check "unrelated ~/.local/bin scripts kept" test -x ~/.local/bin/fix-zscaler
check "stale duplicates moved to the backup" bash -c 'test ! -e ~/.local/bin/uv && test -e ~/.local/state/dotfiles-migration/latest/bin/.local/bin/uv'

section "Git identities"
check "work email by default" bash -c '[ "$(git config user.email)" = alex.borgognoni@deutsche-boerse.com ]'
check "work signing key by default" bash -c '[ "$(git config user.signingkey)" = E69B33C4684313461110E75783E2B86EB1BD39F2 ]'
mkdir -p ~/personal/repo && git -C ~/personal/repo init -q
check "personal email under ~/personal" bash -c '[ "$(git -C ~/personal/repo config user.email)" = alex.bor0419@gmail.com ]'
check "personal signing key under ~/personal" bash -c '[ "$(git -C ~/personal/repo config user.signingkey)" = A7B3752F07393182FB899C11D5A5A7F2739FC452 ]'
check "old ~/.gitconfig no longer overrides" test ! -e ~/.gitconfig

section "SSH and GPG keys (sops)"
check "work key is ~/.ssh/id_ed25519" bash -c 'ssh-keygen -y -f ~/.ssh/id_ed25519 | grep -q AAAAICx+cqOXmeVOKmE6pOjeoiDOIY6DpS9QMulJDFgLJC7w'
check "personal key is ~/.ssh/id_ed25519_personal" bash -c 'ssh-keygen -y -f ~/.ssh/id_ed25519_personal | grep -q AAAAIAAoxgUAc1803bi1jrE64lTyEZYHR4ADVvUONz0S0UJg'
check "private keys are owner-only" bash -c '[ "$(stat -L -c %a ~/.ssh/id_ed25519)" = 400 ] && [ "$(stat -L -c %a ~/.ssh/id_ed25519_personal)" = 400 ]'
check "ssh config: github.com uses the personal key" bash -c 'ssh -G github.com | grep -q "identityfile ~/.ssh/id_ed25519_personal"'
check "ssh config: GitHub Enterprise uses the work key" bash -c 'ssh -G github.deutsche-boerse.de | grep -q "identityfile ~/.ssh/id_ed25519$"'
check "both GPG secret keys imported" bash -c '/usr/bin/gpg --list-secret-keys D5A5A7F2739FC452 E69B33C4684313461110E75783E2B86EB1BD39F2'
check "GPG keys ultimately trusted" bash -c '/usr/bin/gpg --list-keys --with-colons D5A5A7F2739FC452 | grep -q "^pub:u:"'
cd "$HOME/personal/repo" && echo hi > f && git add f
check "signed commit with the personal key" bash -c 'git commit -q -m test && git log --show-signature -1 2>&1 | grep -q D5A5A7F2739FC452'
cd "$HOME" || exit 1

section "Neovim, tmux, kitty config"
probe="$(cd /tmp && nvim --headless "+lua vim.defer_fn(function() io.stdout:write(vim.g.colors_name .. '|' .. vim.fn.execute('messages')) vim.cmd('qa!') end, 3000)" 2>&1)"
[[ "$probe" == theme-catppuccin-macchiato* && "$probe" != *Error* ]] && ok "nvim starts themed, no errors" || bad "nvim" "$probe"
check "nvim language servers available" bash -c 'nvim --headless "+lua io.stdout:write(vim.fn.executable(\"nixd\") .. vim.fn.executable(\"pyright\"))" +qa | grep -q 11'
check "tmux loads config + live theme" bash -c 'tmux new-session -d -s t && tmux source-file ~/.config/tmux/theme-reload.conf && [ "$(tmux show -gv @thm_bg)" = "#24273a" ]; r=$?; tmux kill-server; exit $r'
check "kitty config includes the live theme" grep -q "theme/current/kitty.conf" ~/.config/kitty/kitty.conf

section "Theme engine (terminal side)"
check "all themes available" bash -c '[ "$(theme list | wc -l)" = 15 ]'
check "apply nord" bash -c 'theme apply nord >/dev/null 2>&1; readlink ~/.local/state/theme/current | grep -q theme-pack-nord-'
check "bat follows the theme (Stylix)" bash -c 'grep -qi nord ~/.config/bat/config || ls ~/.config/bat/themes | grep -qi base16'
check "accent per theme" bash -c 'theme accent green >/dev/null && readlink ~/.local/state/theme/current | grep -q nord-green'
check "back to default, accent remembered for nord" bash -c 'theme apply catppuccin-macchiato >/dev/null && theme apply nord >/dev/null && readlink ~/.local/state/theme/current | grep -q nord-green && theme apply catppuccin-macchiato >/dev/null'
check "GTK left alone (no toolkit theming on Ubuntu)" test ! -e ~/.config/gtk-3.0/gtk.css

section "Hyprland desktop (extra session)"
check "session wrapper installed" inzsh 'command -v hyprland-session'
check "Hyprland and Noctalia installed" inzsh 'command -v Hyprland && command -v noctalia'
check "Hyprland config generated" test -s ~/.config/hypr/hyprland.lua
check "graphical session units (Home Manager systemd integration)" test -e ~/.config/systemd/user/hyprland-session.target
check "PipeWire selected, PulseAudio masked" bash -c '[ "$(readlink -f ~/.config/systemd/user/pulseaudio.service)" = /dev/null ] && [ -L ~/.config/systemd/user/sockets.target.wants/pipewire-pulse.socket ]'

section "Packages"
missing=""
for c in claude codex copilot opencode forge terraform kubectl kubecolor k9s aws az func azcopy cf ansible \
         node pnpm bun tsc rustup go uv poetry python3 psql semgrep zizmor sops age 7zz tokei ffmpeg magick \
         pdflatex latexmk kitty code neovide obsidian vlc obs audacity inkscape foliate readest openwhispr \
         chromium wine teams-for-linux nh home-manager theme eza bat fzf rg fd zoxide yazi lazygit btop \
         starship gh git-filter-repo claude-vertex claude-copilot; do
  inzsh "command -v $c" >/dev/null 2>&1 || missing="$missing $c"
done
[ -z "$missing" ] && ok "all expected commands present" || bad "missing commands:$missing"
check "Chrome/Edge not installed by Nix (apt on this machine)" bash -c '! command -v google-chrome-stable && ! command -v microsoft-edge'
check "Python libraries" python3 -c 'import pandas, boto3, openpyxl, docx, pptx, pypdf, pikepdf'
check "CLIs run" inzsh 'forge --version && terraform version && kubectl version --client && node --version && kitty --version'

section "Generic Linux integration and GPU"
check "non-nixos-gpu-setup available" inzsh 'command -v non-nixos-gpu-setup'
check "NVIDIA 595.84 libraries built and used" inzsh 'nix-store -qR "$(readlink -f "$(command -v non-nixos-gpu-setup)")" | grep -q nvidia-x11-595.84'
check "app grid paths (XDG_DATA_DIRS)" inzsh 'echo "$XDG_DATA_DIRS" | grep -q nix-profile/share'
check "fonts visible to fontconfig" inzsh 'nix shell nixpkgs#fontconfig -c fc-list | grep -q "JetBrainsMono Nerd"'

section "Activate again (idempotent)"
check "second switch succeeds" inzsh "home-manager switch --flake $dotfiles/nix#$config -b hm-backup"
check "no duplicate GPG import" bash -c '[ "$(/usr/bin/gpg --list-secret-keys --with-colons | grep -c ^sec)" = 2 ]'
check "migrating again moves nothing, keeps the chezmoi backup" bash -c 'before=$(readlink -f ~/.local/state/dotfiles-migration/latest); "'"$dotfiles"'/scripts/migrate-to-home-manager.sh" "'"$config"'" >/tmp/migrate2.log 2>&1 && grep -q "Already migrated" /tmp/migrate2.log && [ "$(readlink -f ~/.local/state/dotfiles-migration/latest)" = "$before" ] && test -e ~/.zshrc'

section "Roll back to chezmoi"
if "$dotfiles/scripts/rollback-to-chezmoi.sh" > /tmp/rollback.log 2>&1; then ok "rollback script"; else bad "rollback script" "$(tail -10 /tmp/rollback.log)"; fi
check "old .gitconfig restored" grep -q "alex.borgognoni@deutsche-boerse.com" ~/.gitconfig
check "old .zshrc restored" grep -q zinit ~/.zshrc
check "kitty config restored" bash -c '! grep -q theme/current ~/.config/kitty/kitty.conf'
check "stale binaries restored" test -x ~/.local/bin/uv
check "Home Manager files gone" test ! -e ~/.config/zsh/.zshrc

printf '\nPASS=%d FAIL=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
