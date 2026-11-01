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
#   assets/         the font, cursor and icon libraries the themes pick from
#   accents.nix     accent palettes
#   wallpapers.nix  recoloring and image listing
#   pack.nix        the live color files of one theme and accent
#   default.nix     this file: assembles the above
{
  pkgs,
  lib,
  base16,
  # The themes; checks/theme.nix passes broken ones to prove they are rejected
  catalogue ? null,
}:
let
  scheme = name: "${pkgs.base16-schemes}/share/themes/${name}.yaml";
  wallpapers = ../assets/wallpapers;

  inherit (import ./wallpapers.nix { inherit pkgs lib; }) recolor imageFiles;
  inherit (import ./defaults.nix { }) defaults squareDecoration;
  assets = {
    fonts = import ./assets/fonts.nix { inherit pkgs; };
    cursors = import ./assets/cursors.nix { inherit pkgs; };
    icons = import ./assets/icons.nix { inherit pkgs; };
    animations = import ./assets/animations.nix { inherit lib; };
    tmuxShapes = import ./assets/tmux-shapes.nix;
  };
  # An asset a theme names, or a clear error listing what exists
  pick =
    theme: kind: set: key:
    assert lib.assertMsg (set ? ${key})
      "theme ${theme}: unknown ${kind} '${key}' (one of: ${lib.concatStringsSep ", " (lib.attrNames set)})";
    set.${key};
  inherit (import ./accents.nix { inherit lib; }) base16Accents catppuccin;
  mkPack = import ./pack.nix { inherit pkgs lib; };

  mkTheme =
    name: attrs:
    let
      chosen = lib.recursiveUpdate defaults (
        lib.removeAttrs attrs [
          "recolor"
          "defaultWallpaper"
          "scheme"
          "extraAccents"
        ]
      );
      inRange =
        lo: hi: v:
        v >= lo && v <= hi;
      check =
        what: ok:
        assert lib.assertMsg ok "theme ${name}: ${what}";
        true;
      validated =
        check "opacity values must be between 0 and 1" (
          lib.all (inRange 0 1) (lib.attrValues chosen.opacity)
        )
        && check "decoration.rounding, borderSize, gaps and shadow/blur sizes must not be negative" (
          lib.all (k: chosen.decoration.${k} >= 0) [
            "rounding"
            "borderSize"
            "gapsIn"
            "gapsOut"
            "shadowRange"
            "blurSize"
            "blurPasses"
          ]
        )
        && check "decoration.borderStyle must be gradient or solid" (
          lib.elem chosen.decoration.borderStyle [
            "gradient"
            "solid"
          ]
        )
        && check "animation.speed must be above 0" (chosen.animation.speed > 0)
        && check "animation.wallpaper transition and duration are required" (
          chosen.animation.wallpaper == null
          || (chosen.animation.wallpaper ? transition && chosen.animation.wallpaper ? duration)
        );
      animationPreset = pick name "animation preset" assets.animations.presets chosen.animation.preset;
      merged =
        assert validated;
        lib.removeAttrs chosen [
          "mono"
          "ui"
          "cursorSize"
          "fontSizes"
          "tmuxShape"
        ]
        // {
          animation = assets.animations.resolve animationPreset chosen.animation.speed // {
            inherit (chosen.animation) preset speed;
            wallpaper =
              if chosen.animation.wallpaper == null then
                animationPreset.wallpaper
              else
                chosen.animation.wallpaper;
          };
          tmux = {
            shape = chosen.tmuxShape;
            glyphs = pick name "tmux shape" assets.tmuxShapes chosen.tmuxShape;
          };
          fonts = {
            monospace = pick name "mono font" assets.fonts.mono chosen.mono;
            sansSerif = pick name "UI font" assets.fonts.ui chosen.ui;
            serif = assets.fonts.serif.noto-serif;
            sizes = chosen.fontSizes;
          };
          cursor = pick name "cursor" assets.cursors chosen.cursor // {
            size = chosen.cursorSize;
          };
          icons = pick name "icon set" assets.icons chosen.icons;
        };
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

  themes = lib.mapAttrs mkTheme (
    if catalogue == null then
      import ./catalogue.nix { inherit catppuccin squareDecoration; }
    else
      catalogue
  );
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
      ;
    # (Stylix has no "inactive": that one is Hyprland's alone)
    opacity = {
      inherit (theme.opacity)
        terminal
        desktop
        popups
        applications
        ;
    };
    image = theme.wallpaper;
    icons = theme.icons // {
      enable = true;
    };
  };
}
