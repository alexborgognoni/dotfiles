# What every theme starts from (fonts, cursor, icons, opacity, window
# decoration) and the decoration shared by the square themes.
{ pkgs }:
let
  fonts = {
    jetbrains = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    inter = {
      package = pkgs.inter;
      name = "Inter";
    };
    notoSerif = {
      package = pkgs.noto-fonts;
      name = "Noto Serif";
    };
  };

  defaults = {
    polarity = "dark";
    # Accent: names a color in the theme's accent palette (see `accentPalette`).
    # It colors borders, the focused workspace, launcher, clock and the
    # current tmux window; the user can pick another one with `theme accent`.
    # accent2 is the second stop of the active border gradient.
    accent = "blue";
    accent2 = "purple";
    fonts = {
      monospace = fonts.jetbrains;
      sansSerif = fonts.inter;
      serif = fonts.notoSerif;
      sizes = {
        terminal = 12;
        applications = 11;
        desktop = 11;
        popups = 11;
      };
    };
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    icons = {
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };
    opacity = {
      terminal = 0.95;
      desktop = 0.9;
      popups = 0.95;
      applications = 1.0;
    };
    decoration = {
      rounding = 10;
      borderSize = 2;
      gapsIn = 5;
      gapsOut = 10;
      shadow = true;
      blur = true;
      # Noctalia: 0 = square, 1 = default, 2 = extra rounded
      shellRadius = 1.0;
    };
  };

  squareDecoration = {
    rounding = 0;
    borderSize = 3;
    blur = false;
    shellRadius = 0.0;
  };
in
{
  inherit defaults squareDecoration;
}
