# A theme pack: ready-made color files of one theme and accent for the
# programs that switch live (kitty, tmux, Neovim, Hyprland, Noctalia, Readest),
# plus the wallpapers and the accent. mkPack theme accentName -> directory.
{ pkgs, lib }:
let
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
      # Readest custom theme "Theme" (readest-theme-sync writes it into its
      # settings); same colors for both modes, the theme decides.
      readestVariant = {
        fg = c.base05;
        bg = c.base00;
        primary = accent;
      };
      readest = builtins.toJSON {
        name = "theme";
        label = "Theme";
        colors = {
          light = readestVariant;
          dark = readestVariant;
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
        name = "readest.json";
        path = pkgs.writeText "readest.json" readest;
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
in
mkPack
