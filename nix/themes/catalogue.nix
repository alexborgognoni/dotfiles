# The themes: only what differs from `defaults` (defaults.nix). A theme name is
# a base16 scheme of nixpkgs' base16-schemes (or set `scheme`).
#   accent, accent2     names from the accent palette (accents.nix)
#   polarity            "light" for light themes
#   decoration          rounding, borders, blur, shell radius (defaults.nix)
#   recolor = false     keep the wallpapers as they are
#   defaultWallpaper    file name of the first wallpaper
#   extraAccents        named accents (catppuccin)
{ catppuccin, squareDecoration }:
{
  catppuccin-macchiato = {
    extraAccents = catppuccin.macchiato;
    accent = "mauve";
    accent2 = "blue";
    recolor = false;
    defaultWallpaper = "artificial-valley.jpg";
  };
  catppuccin-mocha = {
    extraAccents = catppuccin.mocha;
    accent = "mauve";
    accent2 = "blue";
    recolor = false;
    defaultWallpaper = "catppuccin-spiderman.png";
  };
  catppuccin-latte = {
    polarity = "light";
    extraAccents = catppuccin.latte;
    accent = "mauve";
    accent2 = "blue";
  };

  tokyo-night-dark.accent = "purple";
  tokyo-night-storm = { };

  gruvbox-dark-medium = {
    accent = "yellow";
    accent2 = "orange";
    decoration = squareDecoration;
  };
  gruvbox-light-medium = {
    polarity = "light";
    accent = "orange";
    accent2 = "yellow";
    decoration = squareDecoration;
  };

  rose-pine.accent = "purple";
  rose-pine.accent2 = "pink";
  rose-pine.decoration = {
    rounding = 14;
    shellRadius = 1.5;
  };
  nord = {
    accent2 = "cyan";
    decoration.rounding = 6;
  };
  everforest = {
    accent = "green";
    accent2 = "cyan";
  };
  kanagawa = { };
  dracula = {
    accent = "purple";
    accent2 = "pink";
  };
  onedark = { };

  solarized-dark.decoration = {
    rounding = 4;
    shellRadius = 0.5;
  };
  solarized-light = {
    polarity = "light";
    decoration = {
      rounding = 4;
      shellRadius = 0.5;
    };
  };
}
