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
      # Hyprland + Noctalia (session "Hyprland (Nix)"); GNOME stays as backup
      desktop.enable = true;
    };

    # Edge stays on apt (corporate: Intune/Entra sign-in); Chrome is Nix
    # (home.packages above), same profile (~/.config/google-chrome) and policies
    # (/etc/opt/chrome).
    packages.groups = [
      "cli"
      "gui"
    ];

    # US first (the lock screen and new windows start in it), GB second;
    # Super+Space switches every keyboard (shown in Noctalia's bar)
    keyboard.layout = "us,gb";

    desktop = {
      # Stylix themes GTK, Qt, the cursor (and GNOME, now only the backup
      # session) per theme, as on NixOS
      themeToolkits = true;

      # AirPods in the bar (Noctalia plugin + patched librepods daemon)
      airpods.enable = true;

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
          # Chrome's window is owned by a process further down the launch
          # chain, so a class rule places it (all Chrome windows, as GNOME's
          # auto-move-windows did; web apps have their own class)
          command = "google-chrome-stable";
          workspace = 2;
          class = "^google-chrome$";
        }
        {
          # Teams web app (Chrome)
          command = "google-chrome-stable --profile-directory=Default --app-id=cifhbcnohmdccbgoicgdjpfamggdegmo";
          workspace = 3;
          class = "^chrome-cifhbcnohmdccbgoicgdjpfamggdegmo-Default$";
        }
        {
          # Outlook web app (Chrome); its window belongs to the running Chrome
          command = "google-chrome-stable --profile-directory=Default --app-id=faolnafnngnfdaknnbpnkhgohbobgegn";
          workspace = 4;
          class = "^chrome-faolnafnngnfdaknnbpnkhgohbobgegn-Default$";
        }
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
