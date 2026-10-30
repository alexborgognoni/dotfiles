# Entra ID single sign-on in the browsers (Siemens' linux-entra-sso, package in
# packages/linux-entra-sso): the host program that asks Intune's identity broker
# over D-Bus, and the browser extension that injects the token.
#   Chrome   the host is registered here; the extension comes from the Chrome
#            Web Store (it updates itself, and needs a matching host)
#   Firefox  the host is made known to the Nix Firefox, and the signed extension
#            of the same release is force-installed, both declaratively
# After the first start: click the extension's icon and allow "Access your data
# for login.microsoftonline.com" (Firefox asks the user for host permissions).
# On Firefox SSO is per container: on in the default container only.
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

    programs.firefox = {
      nativeMessagingHosts = [ entraSso ];
      profiles.default.extensions.packages = [ entraSso.firefoxExtension ];
    };
  };
}
