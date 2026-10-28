{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.features.desktop.enable {
    services.playerctld.enable = true;

    home.packages = with pkgs; [
      nautilus
      file-roller
      loupe
      papers
      pavucontrol
      playerctl
      brightnessctl
      libnotify
    ];

    xdg.mimeApps = {
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
