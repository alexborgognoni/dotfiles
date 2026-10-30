# Nix on Ubuntu: the generic-Linux target, Nix in every zsh, Home Manager and
# nh, and a workaround for the distribution's theme prompt.
{
  config,
  lib,
  ...
}:
let
  cfg = config.my;
  home = config.home.homeDirectory;
in
{
  config = lib.mkIf cfg.standalone {
    # XDG paths, app grid entries and session variables for a non-NixOS system
    targets.genericLinux.enable = true;

    # Ubuntu's snapd-desktop-integration offers to install theme snaps that
    # match the GTK theme, icons and cursor (adw-gtk3, Papirus, Bibata: none
    # exists as a snap); "Yes" hangs and the notification cannot be closed.
    # Nothing used here is a snap that needs them.
    home.file.".config/systemd/user/snap.snapd-desktop-integration.snapd-desktop-integration.service" =
      lib.mkIf cfg.features.gui.enable
        {
          source = config.lib.file.mkOutOfStoreSymlink "/dev/null";
        };

    # The Nix installer hooks only interactive shells (/etc/zsh/zshrc); load
    # Nix for every zsh (scripts, ssh commands, the display manager's login
    # shell). The script guards against being sourced twice.
    programs.zsh.envExtra = ''
      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi

      # The login shell is the distribution's zsh (so logging in works even
      # without Nix); interactive shells hand over to Nix's zsh, whose
      # plugins (fzf-tab's module) need Nix's newer glibc. Non-interactive
      # shells and scripts keep running in the shell they were started in.
      if [[ -o interactive && -z ''${HM_NIX_ZSH-} ]]; then
        hm_nix_zsh="$HOME/.nix-profile/bin/zsh"
        if [[ -x $hm_nix_zsh && $(readlink -f /proc/$$/exe) != $(readlink -f $hm_nix_zsh) ]]; then
          export HM_NIX_ZSH=1
          hm_zsh_opts=(-i)
          [[ -o login ]] && hm_zsh_opts+=(-l)
          if [[ -n ''${ZSH_EXECUTION_STRING-} ]]; then
            exec "$hm_nix_zsh" "''${hm_zsh_opts[@]}" -c "$ZSH_EXECUTION_STRING"
          fi
          exec "$hm_nix_zsh" "''${hm_zsh_opts[@]}"
        fi
        unset hm_nix_zsh
      fi
    '';

    programs.home-manager.enable = true;

    programs.nh = {
      enable = true;
      homeFlake = "${home}/dotfiles/nix";
    };
  };
}
