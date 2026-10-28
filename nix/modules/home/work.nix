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

  # pip installs through the corporate Artifactory mirror
  xdg.configFile."pip/pip.conf".text = ''
    [global]
    index-url = https://artifactory.dbgcloud.io/artifactory/api/pypi/pypi.python.org/simple
    trusted-host = pypi.org
        artifactory.dbgcloud.io
    extra-index-url = https://pypi.org/simple
  '';
}
