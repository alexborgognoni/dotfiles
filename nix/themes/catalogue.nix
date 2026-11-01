# The themes: only what differs from `defaults` (defaults.nix). A theme name is
# a base16 scheme of nixpkgs' base16-schemes (or set `scheme`).
#   accent, accent2     names from the accent palette (accents.nix)
#   polarity            "light" for light themes
#   mono, ui            terminal/editor font and UI font (assets/fonts.nix)
#   cursor, icons       cursor and icon set (assets/cursors.nix, icons.nix);
#                       the icon set draws Nautilus's folders and files too
#   decoration          rounding, borders, shadow, blur, shell radius (defaults.nix)
#   opacity             terminal, desktop (bar), popups, applications, inactive
#   animation           preset (assets/animations.nix), speed, wallpaper transition
#   tmuxShape           round, arrow, slant, flame, square (assets/tmux-shapes.nix)
#   recolor = false     keep the wallpapers as they are
#   defaultWallpaper    file name of the first wallpaper
#   extraAccents        named accents (catppuccin)
{ catppuccin, squareDecoration }:
{
  catppuccin-macchiato = {
    mono = "jetbrains";
    ui = "inter";
    cursor = "catppuccin-macchiato";
    icons = "catppuccin-macchiato";
    # The defaults: Hyprland's own look
    extraAccents = catppuccin.macchiato;
    accent = "mauve";
    accent2 = "blue";
    recolor = false;
    defaultWallpaper = "artificial-valley.jpg";
  };
  catppuccin-mocha = {
    mono = "monaspace";
    ui = "geist";
    cursor = "catppuccin-mocha";
    icons = "catppuccin-mocha";
    decoration = {
      blurSize = 4;
      blurPasses = 3;
    };
    opacity.terminal = 0.92;
    extraAccents = catppuccin.mocha;
    accent = "mauve";
    accent2 = "blue";
    recolor = false;
    defaultWallpaper = "catppuccin-spiderman.png";
  };
  catppuccin-latte = {
    polarity = "light";
    mono = "fira-code";
    ui = "nunito";
    cursor = "catppuccin-latte";
    icons = "catppuccin-latte";
    decoration = {
      shadowRange = 8;
      blurSize = 2;
    };
    opacity = {
      terminal = 0.97;
      desktop = 0.92;
    };
    animation.speed = 1.2;
    extraAccents = catppuccin.latte;
    accent = "mauve";
    accent2 = "blue";
  };

  tokyo-night-dark = {
    accent = "purple";
    mono = "iosevka";
    ui = "figtree";
    cursor = "phinger-dark";
    icons = "tela-blue";
    decoration = {
      rounding = 12;
      shadowRange = 14;
      shadowPower = 2;
      shadowGlow = true;
    };
    opacity.terminal = 0.92;
    animation.speed = 1.1;
    tmuxShape = "slant";
  };
  tokyo-night-storm = {
    mono = "commit";
    ui = "work-sans";
    cursor = "phinger-dark";
    icons = "tela-purple";
    decoration = {
      rounding = 8;
      shadowRange = 10;
      shadowGlow = true;
    };
    animation.preset = "snappy";
    tmuxShape = "slant";
  };

  gruvbox-dark-medium = {
    mono = "mononoki";
    ui = "overpass";
    cursor = "gruvbox-orange";
    icons = "gruvbox-plus";
    accent = "yellow";
    accent2 = "orange";
    decoration = squareDecoration;
    opacity.terminal = 1.0;
    animation.preset = "snappy";
    tmuxShape = "square";
  };
  gruvbox-light-medium = {
    polarity = "light";
    mono = "mononoki";
    ui = "overpass";
    cursor = "gruvbox-black";
    icons = "gruvbox-plus";
    accent = "orange";
    accent2 = "yellow";
    decoration = squareDecoration;
    opacity.terminal = 1.0;
    animation.preset = "snappy";
    tmuxShape = "square";
  };

  rose-pine = {
    accent = "purple";
    accent2 = "pink";
    mono = "victor";
    ui = "quicksand";
    cursor = "rose-pine";
    icons = "rose-pine";
    decoration = {
      rounding = 14;
      shadowRange = 10;
      blurSize = 5;
      blurPasses = 3;
      shellRadius = 1.5;
      shellBorders = false;
    };
    opacity = {
      terminal = 0.9;
      desktop = 0.85;
    };
    animation.preset = "slow";
  };
  nord = {
    mono = "meslo";
    ui = "source-sans";
    cursor = "nordzy";
    icons = "nordzy";
    accent2 = "cyan";
    decoration = {
      rounding = 6;
      shadowRange = 6;
    };
    tmuxShape = "arrow";
  };
  everforest = {
    mono = "lilex";
    ui = "nunito";
    cursor = "everforest";
    icons = "everforest";
    accent = "green";
    accent2 = "cyan";
    decoration = {
      rounding = 12;
      shadowRange = 10;
      blurSize = 4;
      shellBorders = false;
    };
    animation = {
      preset = "slow";
      speed = 1.1;
    };
  };
  kanagawa = {
    mono = "zed";
    ui = "noto-sans";
    cursor = "layan";
    icons = "kanagawa";
    decoration.rounding = 8;
    animation.wallpaper = {
      transition = [ "wipe" ];
      duration = 600;
    };
    tmuxShape = "slant";
  };
  dracula = {
    mono = "fantasque";
    ui = "poppins";
    cursor = "dracula-purple";
    icons = "dracula";
    accent = "purple";
    accent2 = "pink";
    decoration = {
      shadowRange = 12;
      shadowGlow = true;
    };
    animation.preset = "bouncy";
    tmuxShape = "flame";
  };
  onedark = {
    mono = "caskaydia";
    ui = "roboto";
    cursor = "bibata";
    icons = "papirus-blue";
    decoration.rounding = 8;
    animation.speed = 1.15;
    tmuxShape = "arrow";
  };

  solarized-dark = {
    mono = "sauce-code";
    ui = "work-sans";
    cursor = "capitaine-white";
    icons = "papirus-teal";
    decoration = {
      rounding = 4;
      borderStyle = "solid";
      blur = false;
      shellRadius = 0.5;
    };
    animation.preset = "snappy";
    tmuxShape = "arrow";
  };
  solarized-light = {
    polarity = "light";
    mono = "sauce-code";
    ui = "work-sans";
    cursor = "capitaine";
    icons = "papirus-teal";
    decoration = {
      rounding = 4;
      borderStyle = "solid";
      blur = false;
      shellRadius = 0.5;
    };
    animation.preset = "snappy";
    tmuxShape = "arrow";
  };
}
