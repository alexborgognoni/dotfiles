# Entra ID single sign-on in Chrome: the extension's host tooling.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  entraSso = pkgs.callPackage ../../../packages/linux-entra-sso { };
in
{
  config = lib.mkIf (config.my.corporate.enable && config.my.features.gui.enable) {
    home.file.".config/google-chrome/NativeMessagingHosts/linux_entra_sso.json".source =
      "${entraSso}/share/linux-entra-sso/chrome/linux_entra_sso.json";
  };
}
