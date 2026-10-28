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

    xdg.mimeApps = lib.mkIf (!config.my.standalone) {
      enable = true;
      defaultApplications = {
        "inode/directory" = "org.gnome.Nautilus.desktop";
        "application/pdf" = "org.gnome.Papers.desktop";
        "image/png" = "org.gnome.Loupe.desktop";
        "image/jpeg" = "org.gnome.Loupe.desktop";
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
      };
    };
  };
}
