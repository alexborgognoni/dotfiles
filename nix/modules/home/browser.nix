# Firefox and Zen (a Firefox fork), fully declarative: profile, settings, search
# and extensions (pinned through the NUR input), the same in both. Stylix
# themes Firefox (firefox-gnome-theme with base16 colors, Firefox Color) and
# Zen (its own colors and CSS).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  addons = inputs.nur.legacyPackages.${pkgs.stdenv.hostPlatform.system}.repos.rycee.firefox-addons;

  policies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    DisablePocket = true;
    DontCheckDefaultBrowser = true;
    OfferToSaveLogins = false;
    PasswordManagerEnabled = false;
  };

  # One profile definition for both browsers
  profile = {
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
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  config = lib.mkIf config.my.features.gui.enable {
    stylix.targets.firefox = {
      profileNames = [ "default" ];
      colorTheme.enable = true;
      firefoxGnomeTheme.enable = true;
    };

    programs.firefox = {
      enable = true;
      inherit policies;
      profiles.default = profile;
    };

    # Zen's releases ("beta" is Zen's name for its numbered releases) use their
    # own profile directory (~/.config/zen); the Firefox settings above apply.
    stylix.targets.zen-browser.profileNames = [ "default" ];
    programs.zen-browser = {
      enable = true;
      inherit policies;
      profiles.default = profile;
    };
  };
}
