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
    ./theme.nix
    ./identity.nix
    ./shell
    ./terminal
    ./editor
    ./desktop
    ./browser.nix
    ./fonts.nix
    ./packages.nix
    ./scripts
    ./standalone.nix
    ./work.nix
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
  };

  config = {
    xdg.enable = true;
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
