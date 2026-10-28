# Ubuntu 22.04 work laptop (Intel + NVIDIA RTX A2000, PRIME on-demand),
# standalone Home Manager. Ubuntu keeps the OS, GNOME, drivers, corporate
# software and system services (see ../../ansible/ubuntu.yml); Nix provides
# everything user-level, including the Hyprland session.
#
#   nh home switch            (or: home-manager switch --flake ~/dotfiles/nix#alex@work-laptop)
{ pkgs, ... }:
{
  home.packages = [ pkgs.unstable.google-chrome ];

  home = {
    username = "Alex";
    homeDirectory = "/home/Alex";
    stateVersion = "26.05";
  };

  my = {
    standalone = true;
    profile = "work";

    features = {
      gui.enable = true;
      # Hyprland + Noctalia as an extra GDM session ("Hyprland (Nix)"); GNOME
      # stays available and keeps its look (my.desktop.themeToolkits = false).
      desktop.enable = true;
    };

    # Edge stays on apt (corporate: Intune/Entra sign-in); Chrome is Nix
    # (home.packages above), same profile (~/.config/google-chrome) and policies
    # (/etc/opt/chrome).
    packages.groups = [
      "cli"
      "gui"
    ];

    keyboard.layout = "gb";

    desktop = {
      # Chrome for now; Firefox later (one line)
      browser = "google-chrome.desktop";

      # Session apps (Hyprland). The Zscaler tray starts by itself (its own
      # systemd user unit on graphical-session.target).
      autostart = [
        {
          command = "kitty";
          workspace = 1;
        }
        {
          command = "google-chrome-stable";
          workspace = 2;
        }
        {
          command = "teams-for-linux";
          workspace = 3;
          class = "^teams-for-linux$";
        }
        {
          # Outlook web app (Chrome); its window belongs to the running Chrome
          command = "google-chrome-stable --profile-directory=Default --app-id=faolnafnngnfdaknnbpnkhgohbobgegn";
          workspace = 4;
          class = "^chrome-faolnafnngnfdaknnbpnkhgohbobgegn-Default$";
        }
        { command = "librepods --start-minimized"; }
      ];
    };

    gpu.nvidia = {
      version = "595.84";
      sha256 = "sha256-mcQE5SExvye8ptoCaNzOPr7cenOrF0BxqZXPGmxeugY=";
    };
  };

  # Monitor layouts (port of GNOME's ~/.config/monitors.xml), matched by
  # monitor, not by connector name (those change with docks and the NVIDIA
  # outputs). kanshi applies the profile whose monitors are all connected.
  services.kanshi = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    settings =
      let
        # internal panel: stable connector name; externals: by model
        # ("make model serial" glob, see kanshi(5))
        laptop = "eDP-1";
        lenovo = "*P27h-10*";
        rog = "*ROG PG278QR*";
        msi = "*MP241*";
      in
      [
        {
          profile.name = "laptop";
          profile.outputs = [
            {
              criteria = laptop;
              mode = "2560x1600@165";
              scale = 1.5;
            }
          ];
        }
        {
          # Lenovo above the laptop
          profile.name = "home";
          profile.outputs = [
            {
              criteria = lenovo;
              mode = "2560x1440@60";
              position = "0,0";
            }
            {
              criteria = laptop;
              mode = "2560x1600@165";
              position = "0,1440";
              scale = 1.0;
            }
          ];
        }
        {
          # MSI rotated left (portrait) on the left, ROG in the middle,
          # laptop on the right
          profile.name = "desk";
          profile.outputs = [
            {
              criteria = msi;
              mode = "1920x1080@60";
              transform = "90";
              position = "0,0";
            }
            {
              criteria = rog;
              mode = "2560x1440@165";
              position = "1080,331";
            }
            {
              criteria = laptop;
              mode = "2560x1600@165";
              position = "3640,331";
              scale = 1.0;
            }
          ];
        }
      ];
  };
}
