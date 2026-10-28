# Home Manager modules, usable on NixOS and standalone (e.g. Ubuntu): nothing
# here reads osConfig. NixOS forwards its values through these options
# (modules/nixos/home-manager.nix); standalone configurations set them in
# homes/<machine>.nix.
#
# Feature groups:
#   core     always: shell, git/ssh/gh, tmux, nixvim, CLI tools, theme engine
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
    ./scripts.nix
    ./standalone.nix
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
    };

    desktop.themeToolkits = lib.mkOption {
      type = lib.types.bool;
      default = !config.my.standalone;
      defaultText = lib.literalExpression "!config.my.standalone";
      description = ''
        Theme GTK, Qt and other desktop-wide targets with Stylix. Off by
        default on standalone machines, so the distribution's own desktop
        (GNOME on Ubuntu) and its apps keep their look.
      '';
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
