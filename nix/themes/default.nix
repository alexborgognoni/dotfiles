# Theme catalogue. A theme is a complete "look": base16 colors, wallpaper,
# fonts, cursor, icons, opacity and window decoration. Every theme starts from
# `defaults` and overrides only what it changes.
#
# Each theme also gets a "pack": a store directory with ready-made color files
# for the programs that can switch live (kitty, tmux, Neovim, Hyprland,
# Noctalia). Hovering a theme in the picker points ~/.local/state/theme/current
# at its pack and reloads those programs; applying it additionally activates
# the theme's Home Manager specialisation (GTK, Qt, Firefox, fonts, ...).
#
#   catalogue.nix   the themes (what differs from the defaults): edit here
#   defaults.nix    what every theme starts from
#   accents.nix     accent palettes
#   wallpapers.nix  recoloring and image listing
#   pack.nix        the live color files of one theme and accent
#   default.nix     this file: assembles the above
{
  pkgs,
  lib,
  base16,
}:
let
  scheme = name: "${pkgs.base16-schemes}/share/themes/${name}.yaml";
  wallpapers = ../assets/wallpapers;

  inherit (import ./wallpapers.nix { inherit pkgs lib; }) recolor imageFiles;
  inherit (import ./defaults.nix { inherit pkgs; }) defaults squareDecoration;
  inherit (import ./accents.nix { inherit lib; }) base16Accents catppuccin;
  mkPack = import ./pack.nix { inherit pkgs lib; };

  mkTheme =
    name: attrs:
    let
      merged = lib.recursiveUpdate defaults (
        lib.removeAttrs attrs [
          "recolor"
          "defaultWallpaper"
          "scheme"
          "extraAccents"
        ]
      );
      base16Scheme = scheme (attrs.scheme or name);
      colors = base16.mkSchemeAttrs base16Scheme;
      asEntry = img: {
        name = baseNameOf img;
        path = img;
      };
      shared =
        if attrs.recolor or true then
          map (img: {
            name = "${lib.head (lib.splitString "." (baseNameOf img))}.png";
            path = recolor "${name}-${baseNameOf img}" colors img;
          }) (imageFiles wallpapers)
        else
          map asEntry (imageFiles wallpapers);
      all = map asEntry (imageFiles (wallpapers + "/themes/${name}")) ++ shared;
      preferred = attrs.defaultWallpaper or null;
      wallpaperList = lib.filter (w: w.name == preferred) all ++ lib.filter (w: w.name != preferred) all;
      # Named accents win; generic base16 names that duplicate one are dropped.
      extraAccents = attrs.extraAccents or { };
      accentPalette =
        lib.filterAttrs (
          _: v: !(lib.elem (lib.toLower v) (map lib.toLower (lib.attrValues extraAccents)))
        ) (base16Accents colors.withHashtag)
        // extraAccents;
      theme = merged // {
        inherit
          name
          base16Scheme
          colors
          accentPalette
          ;
        wallpapers = wallpaperList;
        wallpaper = (builtins.head wallpaperList).path;
      };
      packs = lib.mapAttrs (accent: _: mkPack theme accent) accentPalette;
    in
    assert lib.assertMsg (
      accentPalette ? ${theme.accent}
    ) "theme ${name}: unknown accent ${theme.accent}";
    assert lib.assertMsg (
      accentPalette ? ${theme.accent2}
    ) "theme ${name}: unknown accent2 ${theme.accent2}";
    theme
    // {
      inherit packs;
      pack = packs.${theme.accent};
      # <theme>/<accent>/... plus <theme>/default -> the theme's default accent
      packDir = pkgs.linkFarm "theme-${name}" (
        lib.mapAttrsToList (accent: pack: {
          name = accent;
          path = pack;
        }) packs
        ++ [
          {
            name = "default";
            path = packs.${theme.accent};
          }
        ]
      );
    };

  themes = lib.mapAttrs mkTheme (import ./catalogue.nix { inherit catppuccin squareDecoration; });
in
{
  inherit themes;
  default = "catppuccin-macchiato";

  # All packs in one directory: <packs>/<theme>/<accent>/
  packs = pkgs.linkFarm "theme-packs" (
    lib.mapAttrsToList (name: t: {
      inherit name;
      path = t.packDir;
    }) themes
  );

  # The subset of a theme that maps 1:1 onto Stylix options.
  toStylix = theme: {
    inherit (theme)
      base16Scheme
      polarity
      fonts
      cursor
      opacity
      ;
    image = theme.wallpaper;
    icons = theme.icons // {
      enable = true;
    };
  };
}
