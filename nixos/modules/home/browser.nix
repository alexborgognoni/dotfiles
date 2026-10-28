# Firefox, fully declarative: profile, settings, search and extensions
# (pinned through the NUR input). Stylix themes the browser UI
# (firefox-gnome-theme with base16 colors) and Firefox Color.
{
  inputs,
  pkgs,
  ...
}:
let
  addons = inputs.nur.legacyPackages.${pkgs.stdenv.hostPlatform.system}.repos.rycee.firefox-addons;
in
{
  stylix.targets.firefox = {
    profileNames = [ "default" ];
    colorTheme.enable = true;
    firefoxGnomeTheme.enable = true;
  };

  programs.firefox = {
    enable = true;

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
    };

    profiles.default = {
      id = 0;
      isDefault = true;

      extensions = {
        force = true;
        packages = with addons; [
          ublock-origin
          bitwarden
          vimium
        ];
      };

      search = {
        force = true;
        default = "ddg";
      };

      settings = {
        "browser.startup.page" = 3; # restore previous session
        "browser.aboutConfig.showWarning" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.toolbars.bookmarks.visibility" = "never";
        "extensions.autoDisableScopes" = 0;
        "media.ffmpeg.vaapi.enabled" = true;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
      };
    };
  };
}
