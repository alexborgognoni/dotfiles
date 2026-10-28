# Corporate network settings, work profile only (chezmoi: work-only templates).
{ config, lib, ... }:
lib.mkIf (config.my.profile == "work") {
  # pip installs through the corporate Artifactory mirror
  xdg.configFile."pip/pip.conf".text = ''
    [global]
    index-url = https://artifactory.dbgcloud.io/artifactory/api/pypi/pypi.python.org/simple
    trusted-host = pypi.org
        artifactory.dbgcloud.io
    extra-index-url = https://pypi.org/simple
  '';
}
