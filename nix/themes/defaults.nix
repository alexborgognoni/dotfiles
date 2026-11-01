# What every theme starts from (opacity, window decoration, animation, tmux
# shape, the font, cursor and icon choices) and the decoration shared by the
# square themes. The choices name entries of assets/ (fonts, cursors, icons,
# animations, tmux-shapes).
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
    # 0 = see-through, 1 = opaque.
    #   terminal      kitty's background (the text stays sharp)
    #   desktop       Noctalia's bar pills
    #   popups        Noctalia's notifications and popups
    #   applications  every other window, while focused (Hyprland)
    #   inactive      every other window, while not focused
    opacity = {
      terminal = 0.95;
      desktop = 0.9;
      popups = 0.95;
      applications = 1.0;
      inactive = 1.0;
    };
    decoration = {
      rounding = 10;
      roundingPower = 2;
      borderSize = 2;
      # "gradient": accent to accent2; "solid": accent only
      borderStyle = "gradient";
      gapsIn = 5;
      gapsOut = 10;
      shadow = true;
      shadowRange = 4;
      shadowPower = 3;
      # A shadow in the accent color around the window instead of a dark one
      shadowGlow = false;
      blur = true;
      blurSize = 3;
      blurPasses = 2;
      blurVibrancy = 0.1696;
      # Noctalia: 0 = square, 1 = default, 2 = extra rounded
      shellRadius = 1.0;
      # Noctalia: outlines on panels, cards, buttons and popups
      shellBorders = true;
    };
    # preset: one of assets/animations.nix; speed scales every duration (2.0 is
    # twice as fast), in Hyprland and in Noctalia; wallpaper: null takes the
    # preset's transition ({ transition = [ "wipe" ]; duration = 400; })
    animation = {
      preset = "smooth";
      speed = 1.0;
      wallpaper = null;
    };
    # Shape of tmux's status line segments: round, arrow, slant, flame, square
    tmuxShape = "round";
  };

  squareDecoration = {
    rounding = 0;
    borderSize = 3;
    borderStyle = "solid";
    shadowRange = 3;
    blur = false;
    shellRadius = 0.0;
  };
in
{
  inherit defaults squareDecoration;
}
