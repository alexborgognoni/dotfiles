# Theme catalogue. A theme is a complete "look": base16 colors, wallpaper,
# fonts, cursor, icons, opacity and window decoration. Every theme starts from
# `defaults` and overrides only what it changes.
#
# Each theme also gets a "pack": a store directory with ready-made color files
# for the programs that can switch live (kitty, tmux, Neovim, Hyprland,
# Noctalia). Hovering a theme in the picker points ~/.local/state/theme/current
# at its pack and reloads those programs; applying it additionally activates
# the theme's Home Manager specialisation (GTK, Qt, Firefox, fonts, ...).
{
  pkgs,
  lib,
  base16,
}:
let
  scheme = name: "${pkgs.base16-schemes}/share/themes/${name}.yaml";
  wallpapers = ../assets/wallpapers;

  # Recolor a wallpaper to the theme palette (all 16 base16 colors).
  recolor =
    name: colors: image:
    pkgs.runCommand "wallpaper-${name}.png" { nativeBuildInputs = [ pkgs.lutgen ]; } ''
      lutgen apply -o "$out" ${image} -- ${
        lib.concatMapStringsSep " " (n: "'#${colors."base0${n}"}'") [
          "0"
          "1"
          "2"
          "3"
          "4"
          "5"
          "6"
          "7"
          "8"
          "9"
          "A"
          "B"
          "C"
          "D"
          "E"
          "F"
        ]
      }
    '';

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

  # Every theme can use its base16 accent slots (base08-base0F). Slots are
  # semantic, not hues (base0E is "keywords", whatever its color), so they are
  # named by their actual hue; on a clash the lighter one is "light-<hue>".
  hsl =
    hex:
    let
      ch = i: (lib.fromHexString (builtins.substring i 2 (lib.removePrefix "#" hex))) / 255.0;
      r = ch 0;
      g = ch 2;
      b = ch 4;
      mx = lib.max r (lib.max g b);
      mn = lib.min r (lib.min g b);
      d = mx - mn;
      l = (mx + mn) / 2;
      h0 =
        if d == 0 then
          0.0
        else if mx == r then
          60 * ((g - b) / d)
        else if mx == g then
          60 * ((b - r) / d + 2)
        else
          60 * ((r - g) / d + 4);
      h = if h0 < 0 then h0 + 360 else h0;
      s = if d == 0 then 0.0 else d / (1 - (if 2 * l - 1 < 0 then 1 - 2 * l else 2 * l - 1));
    in
    {
      inherit h s l;
    };

  hueName =
    hex:
    let
      c = hsl hex;
    in
    if c.s < 0.15 then
      "gray"
    else if c.h < 12 || c.h >= 345 then
      "red"
    else if c.h < 35 then
      "orange"
    else if c.h < 58 then
      "yellow"
    else if c.h < 80 then
      (if c.l > 0.65 then "yellow" else "lime")
    else if c.h < 150 then
      "green"
    else if c.h < 200 then
      "cyan"
    else if c.h < 232 then
      "blue"
    else if c.h < 300 then
      "purple"
    else
      "pink";

  base16Accents =
    c:
    let
      slots = map (n: c."base0${n}") [
        "8"
        "9"
        "A"
        "B"
        "C"
        "D"
        "E"
        "F"
      ];
      # The first slot of a hue gets the plain name; later ones become
      # light-<hue> / deep-<hue> (relative to it), or <hue>-2 as a last resort.
      add =
        acc: hex:
        let
          name = hueName hex;
          variant = if (hsl hex).l > (hsl acc.${name}).l then "light-${name}" else "deep-${name}";
          free = n: !(acc ? ${n});
          chosen =
            if free name then
              name
            else if free variant then
              variant
            else
              lib.findFirst free "${name}-x" (map (i: "${name}-${toString i}") (lib.range 2 9));
        in
        acc // { ${chosen} = hex; };
    in
    lib.foldl' add { } (lib.unique slots);

  catppuccin = {
    macchiato = {
      rosewater = "#f4dbd6";
      flamingo = "#f0c6c6";
      pink = "#f5bde6";
      mauve = "#c6a0f6";
      red = "#ed8796";
      maroon = "#ee99a0";
      peach = "#f5a97f";
      yellow = "#eed49f";
      green = "#a6da95";
      teal = "#8bd5ca";
      sky = "#91d7e3";
      sapphire = "#7dc4e4";
      blue = "#8aadf4";
      lavender = "#b7bdf8";
    };
    mocha = {
      rosewater = "#f5e0dc";
      flamingo = "#f2cdcd";
      pink = "#f5c2e7";
      mauve = "#cba6f7";
      red = "#f38ba8";
      maroon = "#eba0ac";
      peach = "#fab387";
      yellow = "#f9e2af";
      green = "#a6e3a1";
      teal = "#94e2d5";
      sky = "#89dceb";
      sapphire = "#74c7ec";
      blue = "#89b4fa";
      lavender = "#b4befe";
    };
    latte = {
      rosewater = "#dc8a78";
      flamingo = "#dd7878";
      pink = "#ea76cb";
      mauve = "#8839ef";
      red = "#d20f39";
      maroon = "#e64553";
      peach = "#fe640b";
      yellow = "#df8e1d";
      green = "#40a02b";
      teal = "#179299";
      sky = "#04a5e5";
      sapphire = "#209fb5";
      blue = "#1e66f5";
      lavender = "#7287fd";
    };
  };

  squareDecoration = {
    rounding = 0;
    borderSize = 3;
    blur = false;
    shellRadius = 0.0;
  };

  # Wallpapers: the shared set in assets/wallpapers/ (recolored to the
  # palette unless the theme sets `recolor = false`), plus any images in
  # assets/wallpapers/themes/<theme>/. The first one is the default.
  imageFiles =
    dir:
    lib.optionals (builtins.pathExists dir) (
      map (f: dir + "/${f}") (
        lib.sort lib.lessThan (
          lib.attrNames (
            lib.filterAttrs (f: type: type == "regular" && builtins.match ".*\\.(png|jpe?g|webp)" f != null) (
              builtins.readDir dir
            )
          )
        )
      )
    );

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

  # ---------------------------------------------------------------- packs --
  hexDigits = [
    "0"
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "A"
    "B"
    "C"
    "D"
    "E"
    "F"
  ];

  mkPack =
    theme: accentName:
    let
      c = theme.colors.withHashtag;
      raw = theme.colors;
      d = theme.decoration;
      accent = theme.accentPalette.${accentName};
      # Gradient partner; fall back to a solid border if it would be identical.
      accent2 =
        if theme.accent2 == accentName then
          theme.accentPalette.${theme.accent}
        else
          theme.accentPalette.${theme.accent2};
      bare = lib.removePrefix "#";
      luaBool = b: if b then "true" else "false";

      kitty = ''
        foreground ${c.base05}
        background ${c.base00}
        selection_foreground ${c.base00}
        selection_background ${c.base05}
        cursor ${c.base05}
        cursor_text_color ${c.base00}
        url_color ${c.base04}
        active_border_color ${c.base03}
        inactive_border_color ${c.base01}
        bell_border_color ${c.base0A}
        active_tab_foreground ${c.base00}
        active_tab_background ${accent}
        inactive_tab_foreground ${c.base04}
        inactive_tab_background ${c.base01}
        tab_bar_background ${c.base01}
        color0 ${c.base00}
        color1 ${c.base08}
        color2 ${c.base0B}
        color3 ${c.base0A}
        color4 ${c.base0D}
        color5 ${c.base0E}
        color6 ${c.base0C}
        color7 ${c.base05}
        color8 ${c.base03}
        color9 ${c.base08}
        color10 ${c.base0B}
        color11 ${c.base0A}
        color12 ${c.base0D}
        color13 ${c.base0E}
        color14 ${c.base0C}
        color15 ${c.base07}
      '';

      # base16 -> catppuccin role mapping for the catppuccin tmux plugin.
      tmux = ''
        set -g @thm_bg "${c.base00}"
        set -g @thm_fg "${c.base05}"
        set -g @thm_rosewater "${c.base06}"
        set -g @thm_flamingo "${c.base0F}"
        set -g @thm_pink "${c.base0E}"
        set -g @thm_mauve "${c.base0E}"
        set -g @thm_red "${c.base08}"
        set -g @thm_maroon "${c.base08}"
        set -g @thm_peach "${c.base09}"
        set -g @thm_yellow "${c.base0A}"
        set -g @thm_green "${c.base0B}"
        set -g @thm_teal "${c.base0C}"
        set -g @thm_sky "${c.base0C}"
        set -g @thm_sapphire "${c.base0D}"
        set -g @thm_blue "${c.base0D}"
        set -g @thm_lavender "${accent}"
        set -g @thm_subtext_1 "${c.base05}"
        set -g @thm_subtext_0 "${c.base04}"
        set -g @thm_overlay_2 "${c.base04}"
        set -g @thm_overlay_1 "${c.base03}"
        set -g @thm_overlay_0 "${c.base03}"
        set -g @thm_surface_2 "${c.base04}"
        set -g @thm_surface_1 "${c.base03}"
        set -g @thm_surface_0 "${c.base02}"
        set -g @thm_mantle "${c.base01}"
        set -g @thm_crust "${c.base01}"
      '';

      nvim = ''
        return {
          name = "${theme.name}",
          polarity = "${theme.polarity}",
          palette = {
        ${lib.concatMapStrings (n: "    base0${n} = \"${c."base0${n}"}\",\n") hexDigits}  },
        }
      '';

      hyprland = ''
        hl.config({
          general = {
            gaps_in = ${toString d.gapsIn},
            gaps_out = ${toString d.gapsOut},
            border_size = ${toString d.borderSize},
            col = {
              active_border = { colors = { "rgb(${bare accent})", "rgb(${bare accent2})" }, angle = 45 },
              inactive_border = "rgb(${raw.base03})",
            },
          },
          decoration = {
            rounding = ${toString d.rounding},
            shadow = { enabled = ${luaBool d.shadow}, color = "rgba(${raw.base00}99)" },
            blur = { enabled = ${luaBool d.blur} },
          },
          misc = { background_color = "rgb(${raw.base00})" },
        })
      '';

      noctaliaVariant = {
        mPrimary = accent;
        mOnPrimary = c.base00;
        mSecondary = accent2;
        mOnSecondary = c.base00;
        mTertiary = c.base0C;
        mOnTertiary = c.base00;
        mError = c.base08;
        mOnError = c.base00;
        mSurface = c.base00;
        mOnSurface = c.base05;
        mSurfaceVariant = c.base01;
        mOnSurfaceVariant = c.base04;
        mOutline = c.base03;
        mShadow = c.base00;
        mHover = c.base02;
        mOnHover = c.base05;
        terminal = {
          background = c.base00;
          foreground = c.base05;
          cursor = c.base05;
          cursorText = c.base00;
          selectionBg = c.base02;
          selectionFg = c.base05;
          normal = {
            black = c.base00;
            red = c.base08;
            green = c.base0B;
            yellow = c.base0A;
            blue = c.base0D;
            magenta = c.base0E;
            cyan = c.base0C;
            white = c.base05;
          };
          bright = {
            black = c.base03;
            red = c.base08;
            green = c.base0B;
            yellow = c.base0A;
            blue = c.base0D;
            magenta = c.base0E;
            cyan = c.base0C;
            white = c.base07;
          };
        };
      };
      # Same colors for both modes: the theme decides light or dark.
      noctalia = builtins.toJSON {
        dark = noctaliaVariant;
        light = noctaliaVariant;
      };
    in
    pkgs.linkFarm "theme-pack-${theme.name}-${accentName}" [
      {
        name = "kitty.conf";
        path = pkgs.writeText "kitty.conf" kitty;
      }
      {
        name = "tmux.conf";
        path = pkgs.writeText "tmux.conf" tmux;
      }
      {
        name = "nvim.lua";
        path = pkgs.writeText "nvim.lua" nvim;
      }
      {
        name = "hyprland.lua";
        path = pkgs.writeText "hyprland.lua" hyprland;
      }
      {
        name = "noctalia.json";
        path = pkgs.writeText "noctalia.json" noctalia;
      }
      {
        name = "wallpaper";
        path = theme.wallpaper;
      }
      {
        name = "wallpapers";
        path = pkgs.linkFarm "wallpapers-${theme.name}" theme.wallpapers;
      }
      {
        name = "polarity";
        path = pkgs.writeText "polarity" theme.polarity;
      }
      {
        name = "accent";
        path = pkgs.writeText "accent" "${accentName} ${accent}";
      }
    ];

  # --------------------------------------------------------------- themes --
  themes = lib.mapAttrs mkTheme {
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
  };
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
