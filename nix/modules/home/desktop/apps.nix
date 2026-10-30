{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.features.desktop.enable {
    services.playerctld.enable = true;

    home.packages =
      with pkgs;
      [
        pavucontrol
        playerctl
        brightnessctl
        libnotify
      ]
      # Standalone distributions already ship a file manager and viewers.
      ++ lib.optionals (!config.my.standalone) [
        nautilus
        file-roller
        loupe
        papers
      ];

    xdg.mimeApps =
      let
        browser = config.my.desktop.browser;
      in
      {
        enable = true;
        defaultApplications = {
          "text/html" = browser;
          "application/xhtml+xml" = browser;
          "x-scheme-handler/http" = browser;
          "x-scheme-handler/https" = browser;
          "x-scheme-handler/about" = browser;
          "x-scheme-handler/unknown" = browser;
        }
        // lib.optionalAttrs (!config.my.standalone) {
          "inode/directory" = "org.gnome.Nautilus.desktop";
          "application/pdf" = "org.gnome.Papers.desktop";
          "image/png" = "org.gnome.Loupe.desktop";
          "image/jpeg" = "org.gnome.Loupe.desktop";
        }
        # As on the Ubuntu laptop before
        // lib.optionalAttrs config.my.standalone {
          "x-scheme-handler/mailto" = browser;
          "x-scheme-handler/postman" = "Postman.desktop";
        };
        associations.added = lib.mkIf config.my.standalone {
          "video/mp4" = "mpv.desktop";
          "video/x-matroska" = "mpv.desktop";
          "application/x-x509-ca-cert" = "org.gnome.gedit.desktop";
        };
      };
  };
}
