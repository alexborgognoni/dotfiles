# The themes: only what differs from `defaults` (defaults.nix). A theme name is
# a base16 scheme of nixpkgs' base16-schemes (or set `scheme`).
#   accent, accent2     names from the accent palette (accents.nix)
#   polarity            "light" for light themes
#   mono, ui            terminal/editor font and UI font (assets/fonts.nix)
#   cursor, icons       cursor and icon set (assets/cursors.nix, icons.nix);
#                       the icon set draws Nautilus's folders and files too
#   decoration          rounding, borders, blur, shell radius (defaults.nix)
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
  };
  tokyo-night-storm = {
    mono = "commit";
    ui = "work-sans";
    cursor = "phinger-dark";
    icons = "tela-purple";
  };

  gruvbox-dark-medium = {
    mono = "mononoki";
    ui = "overpass";
    cursor = "gruvbox-orange";
    icons = "gruvbox-plus";
    accent = "yellow";
    accent2 = "orange";
    decoration = squareDecoration;
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
      shellRadius = 1.5;
    };
  };
  nord = {
    mono = "meslo";
    ui = "source-sans";
    cursor = "nordzy";
    icons = "nordzy";
    accent2 = "cyan";
    decoration.rounding = 6;
  };
  everforest = {
    mono = "lilex";
    ui = "nunito";
    cursor = "everforest";
    icons = "everforest";
    accent = "green";
    accent2 = "cyan";
  };
  kanagawa = {
    mono = "zed";
    ui = "noto-sans";
    cursor = "layan";
    icons = "kanagawa";
  };
  dracula = {
    mono = "fantasque";
    ui = "poppins";
    cursor = "dracula-purple";
    icons = "dracula";
    accent = "purple";
    accent2 = "pink";
  };
  onedark = {
    mono = "caskaydia";
    ui = "roboto";
    cursor = "bibata";
    icons = "papirus-blue";
  };

  solarized-dark = {
    mono = "sauce-code";
    ui = "work-sans";
    cursor = "capitaine-white";
    icons = "papirus-teal";
    decoration = {
      rounding = 4;
      shellRadius = 0.5;
    };
  };
  solarized-light = {
    polarity = "light";
    mono = "sauce-code";
    ui = "work-sans";
    cursor = "capitaine";
    icons = "papirus-teal";
    decoration = {
      rounding = 4;
      shellRadius = 0.5;
    };
  };
}
