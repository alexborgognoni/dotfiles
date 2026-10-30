# pip installs through the corporate Artifactory mirror.
{ config, lib, ... }:
{
  config = lib.mkIf config.my.corporate.enable {
    xdg.configFile."pip/pip.conf".text = ''
      [global]
      index-url = https://artifactory.dbgcloud.io/artifactory/api/pypi/pypi.python.org/simple
      trusted-host = pypi.org
          artifactory.dbgcloud.io
      extra-index-url = https://pypi.org/simple
    '';
  };
}
