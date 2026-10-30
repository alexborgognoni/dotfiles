# Ubuntu system layer with system-manager (NixOS-style /etc files, systemd
# units and tmpfiles on a non-NixOS distribution). Everything here is root
# level; the user level is Home Manager (modules/home, homes/<machine>.nix).
# apt packages, groups and the login shell stay with ansible/ubuntu.yml.
#
#   sudo system-manager switch --flake ~/dotfiles/nix#<machine>
#   (or: nix run ~/dotfiles/nix#system-manager -- switch --flake ... --sudo)
{
  config,
  lib,
  pkgs,
  homeConfig,
  ...
}:
let
  cfg = config.my;
  user = cfg.user;
  home = "/home/${user}";
  ca = "/etc/ssl/certs/ca-certificates.crt";
  keyd = import ../shared/keyd.nix;
  desktop = homeConfig.my.features.desktop.enable;
  portal = pkgs.unstable.xdg-desktop-portal-hyprland;
in
{
  options.my.user = lib.mkOption {
    type = lib.types.str;
    description = "The (single) user whose Home Manager configuration this system serves.";
  };

  config = {
    nixpkgs.hostPlatform = "x86_64-linux";

    # Users and groups belong to Ubuntu (and ansible/ubuntu.yml): never let
    # system-manager write /etc/passwd or /etc/group.
    services.userborn.enable = false;

    # --- Nix ---------------------------------------------------------------
    # Takes over /etc/nix/nix.conf (the installer's file is kept as a backup
    # and restored on deactivation).
    nix = {
      enable = true;
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [ user ];
        auto-optimise-store = true;
        # Corporate root CA (Zscaler) via Ubuntu's trust store: for the
        # daemon's downloads and for source fetches in the build sandbox.
        ssl-cert-file = ca;
        extra-sandbox-paths = [ ca ];
      };
    };
    # (scripts/bootstrap-nix.sh creates it first, so the initial build works)
    environment.etc."systemd/system/nix-daemon.service.d/corporate-ca.conf" = {
      text = ''
        [Service]
        Environment=NIX_SSL_CERT_FILE=${ca}
        Environment=NIX_GIT_SSL_CAINFO=${ca}
      '';
      replaceExisting = true;
    };

    # --- Keyboard remapping (shared with NixOS) -----------------------------
    environment.etc."keyd/default.conf" = {
      # keyd's format: [ids] lists bare device ids, the rest is INI
      text = "[ids]\n" + lib.concatLines keyd.ids + "\n" + lib.generators.toINI { } keyd.settings;
      replaceExisting = true;
    };
    systemd.services.keyd = {
      description = "Key remapping daemon";
      wantedBy = [ "system-manager.target" ];
      restartTriggers = [ config.environment.etc."keyd/default.conf".source ];
      serviceConfig = {
        ExecStart = "${pkgs.keyd}/bin/keyd";
        Restart = "always";
      };
    };

    # --- Your system tweaks (ported from the laptop's /etc) -----------------
    # Present as an Apple device to AirPods (LibrePods); Bluetooth on at boot
    environment.etc."bluetooth/main.conf" = {
      text = ''
        [General]
        DeviceID = bluetooth:004C:0000:0000

        [Policy]
        AutoEnable=true
      '';
      replaceExisting = true;
    };
    # Prefer IPv4 over IPv6
    environment.etc."gai.conf" = {
      text = "precedence ::ffff:0:0/96  100\n";
      replaceExisting = true;
    };
    # File watchers (IDEs, dev servers)
    environment.etc."sysctl.d/40-inotify.conf" = {
      text = "fs.inotify.max_user_watches=524288\n";
      replaceExisting = true;
    };
    # Virtual input devices for user programs
    environment.etc."udev/rules.d/70-uinput.rules" = {
      text = ''KERNEL=="uinput", GROUP="input", MODE="0660", TAG+="uaccess"'' + "\n";
      replaceExisting = true;
    };
    # Chrome from Nix does not pick up the corporate roots from NSS the way the
    # distribution's Chrome did (ERR_CERT_AUTHORITY_INVALID behind Zscaler).
    # Its enterprise policy CACertificates does: built from the CAs IT deploys
    # to /usr/local/share/ca-certificates (nothing corporate in this repo), at
    # boot and on every switch.
    systemd.services.chrome-corporate-cas = {
      description = "Chrome policy: trust the locally installed CA certificates";
      wantedBy = [ "system-manager.target" ];
      after = [ "local-fs.target" ];
      path = [
        pkgs.openssl
        pkgs.coreutils
        pkgs.jq
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        dir=/etc/opt/chrome/policies/managed
        out="$dir/system-manager-local-cas.json"
        mkdir -p "$dir"
        certs=()
        for crt in /usr/local/share/ca-certificates/*.crt /usr/local/share/ca-certificates/*/*.crt; do
          [ -f "$crt" ] || continue
          certs+=("$(openssl x509 -in "$crt" -outform DER | base64 -w0)")
        done
        if [ ''${#certs[@]} -eq 0 ]; then
          rm -f "$out"
          exit 0
        fi
        printf '%s\n' "''${certs[@]}" | jq -R . | jq -s '{ CACertificates: . }' > "$out.tmp"
        chmod 644 "$out.tmp"
        mv "$out.tmp" "$out"
      '';
    };

    # Apply sysctl and udev changes on switch, not only at the next boot
    systemd.services.dotfiles-apply-etc = {
      description = "Apply sysctl and udev settings from system-manager";
      wantedBy = [ "system-manager.target" ];
      restartTriggers = [
        config.environment.etc."sysctl.d/40-inotify.conf".source
        config.environment.etc."udev/rules.d/70-uinput.rules".source
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          "/usr/lib/systemd/systemd-sysctl /etc/sysctl.d/40-inotify.conf"
          "/usr/bin/udevadm control --reload"
          "/usr/bin/udevadm trigger --subsystem-match=misc --sysname-match=uinput"
        ];
      };
    };

    # --- GPU drivers for Nix-built apps --------------------------------------
    # The same driver set Home Manager's targets.genericLinux.gpu defines
    # (Mesa + the pinned NVIDIA libraries), at the path NixOS uses.
    systemd.tmpfiles.rules = [
      "L+ /run/opengl-driver - - - - ${homeConfig.targets.genericLinux.gpu.drivers}"
    ]
    # --- Hyprland session (GDM) and portal --------------------------------
    ++ lib.optionals desktop [
      "L+ /usr/share/wayland-sessions/hyprland-nix.desktop - - - - /etc/dotfiles/hyprland-nix.desktop"
      # Ubuntu's portal frontend only reads backends from /usr/share
      "L+ /usr/share/xdg-desktop-portal/portals/hyprland.portal - - - - ${portal}/share/xdg-desktop-portal/portals/hyprland.portal"
      "L+ /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service - - - - ${portal}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service"
    ];

    # Hyprland is Wayland-only; GDM must offer Wayland sessions. GNOME keeps
    # running on whichever session is chosen (GDM remembers the last one, e.g.
    # "Ubuntu on Xorg"). Ubuntu's GDM has no drop-in directory, so this owns
    # the file (the original is kept and restored on deactivation).
    environment.etc."gdm3/custom.conf" = lib.mkIf desktop {
      text = ''
        # Managed by system-manager (~/dotfiles/nix/modules/system-manager)
        [daemon]
        WaylandEnable=true

        [security]

        [xdmcp]

        [chooser]

        [debug]
      '';
      replaceExisting = true;
    };

    # The portal's D-Bus activation starts this user unit
    environment.etc."systemd/user/xdg-desktop-portal-hyprland.service" = lib.mkIf desktop {
      source = "${portal}/share/systemd/user/xdg-desktop-portal-hyprland.service";
    };

    environment.etc."dotfiles/hyprland-nix.desktop" = lib.mkIf desktop {
      text = ''
        [Desktop Entry]
        Name=Hyprland (Nix)
        Comment=Hyprland and Noctalia from ~/dotfiles (Home Manager)
        Exec=${home}/.nix-profile/bin/hyprland-session
        Type=Application
        DesktopNames=Hyprland
      '';
    };

    # Noctalia's lock screen (patched to use this service, see
    # modules/home/desktop/noctalia.nix) runs Nix's PAM, which cannot parse
    # Ubuntu's /etc/pam.d files (Debian's @include): a stack of its own, with
    # absolute module paths as on NixOS.
    environment.etc."pam.d/noctalia" = lib.mkIf desktop {
      text = ''
        auth     required ${pkgs.linux-pam}/lib/security/pam_unix.so
        account  required ${pkgs.linux-pam}/lib/security/pam_unix.so
      '';
    };

    # Nix-built lock screens use Nix's PAM, whose pam_unix needs the setuid
    # helper at /run/wrappers/bin/unix_chkpwd (as on NixOS).
    security.wrappers.unix_chkpwd = lib.mkIf desktop {
      setuid = true;
      owner = "root";
      group = "root";
      source = "${pkgs.linux-pam}/bin/unix_chkpwd";
    };
  };
}
