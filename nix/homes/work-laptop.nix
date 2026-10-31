# Ubuntu 22.04 work laptop (Intel + NVIDIA RTX A2000, PRIME on-demand),
# standalone Home Manager. Ubuntu keeps the OS, GNOME, drivers, corporate
# software and system services (see ../../apt/); Nix provides
# everything user-level, including the Hyprland session.
#
#   nh home switch            (or: home-manager switch --flake ~/dotfiles/nix#alex@work-laptop)
{ pkgs, ... }:
let
  # Screen scales: the one lever for the size of everything (windows, bar,
  # text, cursor). Valid values give whole logical pixels: for the laptop
  # panel (2560x1600) 1.0, 1.25, 1.6 and 2.0; for the 2560x1440 screens 1.0,
  # 1.25, 2.0. Hyprland rounds anything else (1.5 becomes 1.6).
  scales = {
    laptopAlone = 1.25; # the panel as the only screen
    laptopDocked = 1.0; # the panel next to external screens
    external = 1.0;
  };
in
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

      # Main display: ROG at the desk, Lenovo at the other desk, else the
      # laptop panel. It gets the full bar and workspaces 1-10; the others get
      # the workspaces-only bar and the leftover workspaces.
      mainMonitors = [
        "ROG PG278QR"
        "P27h-10"
      ];

      # AirPods in the bar (Noctalia plugin + patched librepods daemon)
      airpods.enable = true;

      # Voice dictation (Super+Shift+I; Voxtype, local Whisper)
      dictation = {
        enable = true;
        # Whisper picks among these (more accurate than among all ~99)
        languages = [
          "en"
          "de"
          "fr"
        ];
        # ~6x faster than the Intel graphics on this laptop; loaded per
        # dictation (about a second) so the NVIDIA GPU can sleep in between
        gpu = "nvidia";
        onDemandLoading = true;
      };

      # Noctalia plugins (pinned in modules/home/desktop/noctalia/plugin-catalog.nix)
      noctalia.plugins = [
        "bitwarden"
        "color_picker"
        "emoji-picker"
        "file-search"
        "gamer-mode"
        "keybind-cheatsheet"
        "notes"
        "nvtop"
        "pomodoro"
        "printers"
        "voxtype"
        "hyprland-settings"
      ];

      # Chrome for now; Firefox later (one line)
      browser = "google-chrome.desktop";

      # Session apps (Hyprland)
      autostart = [
        {
          # Zscaler tray (modules/home/corporate/zscaler.nix); the GNOME session starts it
          # through Zscaler's own autostart entry
          command = "systemctl --user start zscaler-tray.service";
        }
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
    package = pkgs.unstable.kanshi;
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
              scale = scales.laptopAlone;
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
              scale = scales.external;
            }
            {
              criteria = laptop;
              mode = "2560x1600@165";
              position = "0,1440";
              scale = scales.laptopDocked;
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
              scale = scales.external;
            }
            {
              criteria = rog;
              mode = "2560x1440@165";
              position = "1080,331";
              scale = scales.external;
            }
            {
              criteria = laptop;
              mode = "2560x1600@165";
              position = "3640,331";
              scale = scales.laptopDocked;
            }
          ];
        }
      ];
  };
}
