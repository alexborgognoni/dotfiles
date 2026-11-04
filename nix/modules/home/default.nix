# Home Manager modules, usable on NixOS and standalone (e.g. Ubuntu): nothing
# here reads osConfig. NixOS forwards its values through these options
# (modules/nixos/home-manager.nix); standalone configurations set them in
# homes/<machine>.nix.
#
# Feature groups:
#   core     always: shell, git/ssh/gh, tmux, Neovim (AstroNvim), CLI tools, theme engine
#   gui      kitty, Firefox, fonts (my.features.gui.enable)
#   desktop  Hyprland, Noctalia, desktop apps (my.features.desktop.enable)
{ config, lib, ... }:
{
  imports = [
    ./theme
    ./identity
    ./shell
    ./terminal
    ./editor
    ./desktop
    ./browser.nix
    ./fonts.nix
    ./packages.nix
    ./toolchains.nix
    ./standalone
    ./corporate
    ./apps
    ./gnome
  ];

  options.my = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "personal"
        "work"
      ];
      default = "personal";
      description = "Selects identity-specific settings (git email, SSH keys, CA handling).";
    };

    features = {
      gui.enable = lib.mkEnableOption "graphical applications (kitty, Firefox, fonts)" // {
        default = true;
      };
      desktop.enable = lib.mkEnableOption "the Hyprland desktop (Hyprland, Noctalia, desktop apps)" // {
        default = true;
      };
    };

    standalone = lib.mkEnableOption ''
      standalone Home Manager on a non-NixOS distribution (generic Linux
      integration, GPU drivers, fonts, nh and user-level secrets)
    '';

    foreignBinaries = lib.mkOption {
      type = lib.types.bool;
      default = config.my.standalone || !(import ../../runtimes.nix).patched;
      defaultText = lib.literalExpression "config.my.standalone || !(import ../../runtimes.nix).patched";
      description = ''
        The host may run binaries that Nix did not build: Ubuntu (its own
        loader) always, NixOS (nix-ld) when the runtimes are not patched
        (nix/runtimes.nix). On: mise, uv's standalone Pythons and Gradle's JDK
        downloads. Off: the Nix runtimes only (docs/NATIVE-CODE.md).
      '';
    };

    keyboard.layout = lib.mkOption {
      type = lib.types.str;
      default = "us";
      example = "gb,us";
      description = "XKB layout(s); several, comma-separated, to switch between them (Super+Space).";
    };

    keyboard.options = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "caps:escape";
      description = ''
        XKB options. Not for switching layouts: Hyprland keeps the layout per
        keyboard, so grp:* toggles only reach the keyboard they were pressed on
        (Super+Space switches all).
      '';
    };

    desktop.themeToolkits = lib.mkOption {
      type = lib.types.bool;
      default = !config.my.standalone;
      defaultText = lib.literalExpression "!config.my.standalone";
      description = ''
        Theme GTK, Qt and other desktop-wide targets with Stylix. Off by
        default on standalone machines, so the distribution's own desktop
        and its apps keep their look (GNOME on Ubuntu: ./gnome).
      '';
    };

    desktop.browser = lib.mkOption {
      type = lib.types.str;
      default = "firefox.desktop";
      example = "google-chrome.desktop";
      description = "Default web browser (desktop file name), for links and HTML files.";
    };

    desktop.autostart = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            command = lib.mkOption {
              type = lib.types.str;
              description = "Command started when the desktop session starts.";
            };
            workspace = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Workspace its window opens on (silently, without switching there).";
            };
            class = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Window class (regex) to place on `workspace` with a window rule,
                for apps whose window does not belong to the started process
                (e.g. a Chrome web app handed to a running Chrome). Applies to
                every window of that class. Without it, only the windows of
                this launch are placed.
              '';
            };
          };
        }
      );
      default = [ ];
      description = "Apps started with the desktop session (Hyprland).";
    };

    desktop.monitors = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = "auto";
        }
      ];
      description = "Hyprland monitor definitions (passed to hl.monitor).";
    };

    desktop.mainMonitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "ROG PG278QR" ];
      description = ''
        Main display, by (part of) the monitor description, in order of
        preference: the first one connected wins, otherwise the internal panel.
        The main display keeps the full Noctalia bar and gets workspaces 1-10;
        every other display gets the workspaces-only bar and the leftover
        workspaces. Empty: all displays are alike.
      '';
    };

    desktop.twinScreens = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            match = lib.mkOption {
              type = lib.types.str;
              example = "P27h-10";
              description = "Part of the monitor description the identical screens share.";
            };
            week = lib.mkOption {
              type = lib.types.int;
              example = 15;
              description = ''
                Week of manufacture in the screen's EDID (byte 16), the only
                thing that tells identical screens apart (`od -An -tu1 -j16 -N1
                /sys/class/drm/card*-DP-7/edid`). That screen is kept; the
                others with the same description are switched off.
              '';
            };
          };
        }
      );
      default = [ ];
      description = ''
        Identical screens (same model and serial, e.g. two of the same
        monitor on a dock): keep only the one of that week of manufacture,
        above the internal panel. kanshi cannot tell them apart, so
        `dock-screens` (hyprland/monitors.nix) does it on plug and unplug.
      '';
    };
  };

  config = {
    news.display = "silent";

    xdg.enable = true;
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
