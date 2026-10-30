# Zscaler Client Connector (installed by IT in /opt/zscaler): its tray under
# Hyprland.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.my.corporate.enable && config.my.features.gui.enable) {
    # Zscaler's tray launcher (zstray_desktop.sh) decides whether the tray runs
    # by grepping ps for "ZSTray", which also matches its own
    # `systemctl --user start ZSTray.service`: started from the menu, the tray
    # always took itself for a second instance and aborted. Our entry starts
    # Zscaler's unit file under a second name (zscaler-tray.service) when no
    # tray runs, and passes zsa:// sign-in links on once it does.
    xdg.configFile."systemd/user/zscaler-tray.service" = {
      source = config.lib.file.mkOutOfStoreSymlink "/etc/xdg/systemd/user/ZSTray.service";
    };
    # The tray needs the bar's tray (StatusNotifier watcher) to show its icon,
    # and registers only once, at start. Noctalia counts as started the moment
    # it launches, seconds before its tray exists: started at login, the tray
    # ran without an icon. So: ordering (no Wants: the GNOME session has no
    # Noctalia) and a wait, at most 30 s, for the watcher on the session bus.
    xdg.configFile."systemd/user/zscaler-tray.service.d/10-after-noctalia.conf" = {
      text = ''
        [Unit]
        After=noctalia.service

        [Service]
        ExecStartPre=/bin/sh -c 'for i in $(seq 1 100); do busctl --user list | grep -q org.kde.StatusNotifierWatcher && exit 0; sleep 0.3; done; exit 0'
      '';
    };
    # Our entry has a neutral id too: launchers can pass the id as an argument.
    # Zscaler's own entry is hidden.
    xdg.dataFile."applications/ZSTray.desktop" = {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Zscaler Client Connector
        Hidden=true
      '';
    };
    xdg.mimeApps.defaultApplications."x-scheme-handler/zsa" = "zscaler-tray.desktop";
    xdg.dataFile."applications/zscaler-tray.desktop" = {
      text =
        let
          launch = pkgs.writeShellScript "zscaler-tray-launch" ''
            # Shell builtins only: a helper process with the name in its
            # arguments would trip Zscaler's check itself
            running() {
              local c n
              for c in /proc/[0-9]*/comm; do
                read -r n < "$c" 2>/dev/null && [ "$n" = ZSTray ] && return 0
              done
              return 1
            }
            if ! running; then
              systemctl --user start zscaler-tray.service
              for _ in $(seq 50); do running && break; sleep 0.2; done
            fi
            # Zscaler's script hands over to the running tray: a link (zsa://...)
            # signs in, a plain launch opens the window (the tray icon does too)
            exec /opt/zscaler/scripts/zstray_desktop.sh "$@"
          '';
        in
        ''
          [Desktop Entry]
          Type=Application
          Version=1.0
          Name=Zscaler Client Connector
          Comment=Zscaler Client Connector
          Icon=/opt/zscaler/Images/ZscalerAppTop.png
          Exec=${launch} %u
          Terminal=false
          Categories=Network;Application;
          MimeType=x-scheme-handler/zsa;application/x-zstray;
        '';
    };
  };
}
