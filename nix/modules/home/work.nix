# Corporate settings, work profile only (chezmoi: work-only templates).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  entraSso = pkgs.callPackage ../../packages/linux-entra-sso { };
in
lib.mkIf (config.my.profile == "work") {
  # Entra ID single sign-on in Chrome: the extension's host tooling
  home.file.".config/google-chrome/NativeMessagingHosts/linux_entra_sso.json" =
    lib.mkIf config.my.features.gui.enable
      { source = "${entraSso}/share/linux-entra-sso/chrome/linux_entra_sso.json"; };

  # Zscaler's tray launcher (zstray_desktop.sh) decides whether the tray runs
  # by grepping ps for "ZSTray", which also matches its own
  # `systemctl --user start ZSTray.service`: started from the menu, the tray
  # always took itself for a second instance and aborted. Our entry starts
  # Zscaler's unit file under a second name (zscaler-tray.service) when no
  # tray runs, and passes zsa:// sign-in links on once it does.
  xdg.configFile."systemd/user/zscaler-tray.service" = lib.mkIf config.my.features.gui.enable {
    source = config.lib.file.mkOutOfStoreSymlink "/etc/xdg/systemd/user/ZSTray.service";
  };
  # The tray needs the bar's tray (StatusNotifier watcher) to show its icon;
  # only ordering (no Wants: the GNOME session has no Noctalia)
  xdg.configFile."systemd/user/zscaler-tray.service.d/10-after-noctalia.conf" =
    lib.mkIf config.my.features.gui.enable {
      text = ''
        [Unit]
        After=noctalia.service
      '';
    };
  # Our entry has a neutral id too: launchers can pass the id as an argument.
  # Zscaler's own entry is hidden.
  xdg.dataFile."applications/ZSTray.desktop" = lib.mkIf config.my.features.gui.enable {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Zscaler Client Connector
      Hidden=true
    '';
  };
  xdg.mimeApps.defaultApplications."x-scheme-handler/zsa" =
    lib.mkIf config.my.features.gui.enable "zscaler-tray.desktop";
  xdg.dataFile."applications/zscaler-tray.desktop" = lib.mkIf config.my.features.gui.enable {
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
          # A link (zsa://...) goes to the running tray via Zscaler's script
          [ $# -eq 0 ] || exec /opt/zscaler/scripts/zstray_desktop.sh "$@"
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

  # pip installs through the corporate Artifactory mirror
  xdg.configFile."pip/pip.conf".text = ''
    [global]
    index-url = https://artifactory.dbgcloud.io/artifactory/api/pypi/pypi.python.org/simple
    trusted-host = pypi.org
        artifactory.dbgcloud.io
    extra-index-url = https://pypi.org/simple
  '';
}
