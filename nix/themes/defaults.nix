# What every theme starts from (opacity, window decoration, the font, cursor
# and icon choices) and the decoration shared by the square themes. The
# choices name entries of assets/{fonts,cursors,icons}.nix.
_:
let
  defaults = {
    polarity = "dark";
    # Accent: names a color in the theme's accent palette (see `accentPalette`).
    # It colors borders, the focused workspace, launcher, clock and the
    # current tmux window; the user can pick another one with `theme accent`.
    # accent2 is the second stop of the active border gradient.
    accent = "blue";
    accent2 = "purple";
    # Terminal/editor font, UI font, cursor and icon set (assets/)
    mono = "jetbrains";
    ui = "inter";
    cursor = "bibata";
    icons = "papirus";
    fontSizes = {
      terminal = 12;
      applications = 11;
      desktop = 11;
      popups = 11;
    };
    cursorSize = 24;
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
