# Theme switching with live preview.
#
#   ~/.local/state/theme/
#     packs           -> every theme's packs: packs/<theme>/<accent>/
#     current         -> the pack that live programs read right now
#     selected        the applied theme (survives rebuilds)
#     accents/<theme> the accent chosen for a theme (else its default)
#
# kitty, tmux, Neovim, Hyprland and Noctalia read their colors through
# `current`, so pointing it at another pack and reloading them is instant;
# that is what hovering in the picker does. Applying a theme also activates
# its pre-built Home Manager specialisation, which re-themes everything else
# (GTK, Qt, Firefox, fonts, cursor, icons, ...). The default theme is the base
# generation itself.
#
#   theme                 open the picker (Super+T)
#   theme apply <name>    switch theme
#   theme preview <name>  live-preview without applying
#   theme accent          pick the accent color of the current theme (Super+Shift+T)
#   theme accent <color>  set it directly; `theme accent list` lists them
#   theme list | current
#   theme wallpaper next|previous|random|rotate [on|off|toggle]
{
  config,
  inputs,
  lib,
  pkgs,
  themeCatalogue,
  ...
}:
let
  # Built once per pkgs and passed in as a special argument, so the theme
  # specialisations don't re-evaluate it.
  catalogue = themeCatalogue;
  features = config.my.features;
  # Stylix themes everything (GTK, Qt, ...) only with the desktop feature and
  # toolkit theming; otherwise just the terminal-side programs.
  themeEverything = features.desktop.enable && config.my.desktop.themeToolkits;
  inherit (catalogue) themes packs;
  cfg = config.my.theme;

  # Themes with a pre-built specialisation (plus the default theme).
  prebuilt = config.my.themes.prebuilt;
  available = lib.filterAttrs (
    name: _: name == catalogue.default || prebuilt == null || lib.elem name prebuilt
  ) themes;
  stateDir = "${config.xdg.stateHome}/theme";

  themeCommand = import ./command.nix {
    inherit
      config
      lib
      pkgs
      catalogue
      available
      stateDir
      ;
  };
in
{
  options.my.theme = lib.mkOption {
    type = lib.types.raw;
    default = themes.${catalogue.default};
    description = "The theme of this generation (see themes/).";
  };

  options.my.themes.prebuilt = lib.mkOption {
    type = lib.types.nullOr (lib.types.listOf (lib.types.enum (lib.attrNames themes)));
    default = null;
    example = [
      "nord"
      "dracula"
    ];
    description = ''
      Themes that get a pre-built specialisation (the default theme always
      does); null builds all of them. Fewer themes mean faster rebuilds and
      less evaluation memory.
    '';
  };

  options.my.isThemeSpecialisation = lib.mkOption {
    type = lib.types.bool;
    default = false;
    internal = true;
  };

  options.my.themeState = lib.mkOption {
    type = lib.types.str;
    default = stateDir;
    readOnly = true;
    description = "Directory holding the live theme state (`current` points at the active pack).";
  };

  imports = [ inputs.stylix.homeModules.stylix ];

  config = lib.mkMerge [
    {
      home.packages = [ themeCommand ];

      # Stylix follows this generation's theme (specialisations override
      # my.theme). Without the desktop feature (e.g. Ubuntu with GNOME) only
      # terminal-side programs are themed, not GTK/Qt or the desktop.
      stylix = lib.mkMerge [
        (
          catalogue.toStylix cfg
          // {
            enable = true;
            autoEnable = themeEverything;
          }
        )
        {
          targets.hyprpaper.enable = false;
          # Stylix enables Qt by itself only under NixOS
          targets.qt.enable = themeEverything;
          # Package overlays belong to the package set's owner (NixOS Stylix
          # or nothing); with useGlobalPkgs Home Manager must not add any.
          overlays.enable = false;
        }
        (lib.mkIf (!themeEverything) {
          targets = {
            bat.enable = true;
            btop.enable = true;
            fzf.enable = true;
            lazygit.enable = true;
            yazi.enable = true;
            starship.enable = true;
            kitty.enable = features.gui.enable;
            firefox.enable = features.gui.enable;
          };
        })
      ];

      # Every generation points `current` at its own theme's pack, using the
      # accent the user picked for that theme.
      home.activation.themePack = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        themeState=${lib.escapeShellArg stateDir}
        run mkdir -p "$themeState/accents"
        run ln -sfn ${packs} "$themeState/packs"
        themeAccent=default
        if [ -f "$themeState/accents/${cfg.name}" ] \
          && [ -e "${cfg.packDir}/$(cat "$themeState/accents/${cfg.name}")" ]; then
          themeAccent="$(cat "$themeState/accents/${cfg.name}")"
        fi
        run ln -sfn "$(readlink -f "${cfg.packDir}/$themeAccent")" "$themeState/current"
      '';

      # Let running programs pick up the (possibly new) pack.
      home.activation.themeReload =
        lib.hm.dag.entryAfter [ "themePack" "onFilesChange" "themeRestore" ]
          ''
            run ${themeCommand}/bin/theme reload || true
          '';

    }

    (lib.mkIf (!config.my.isThemeSpecialisation) {
      specialisation = lib.mapAttrs (_: theme: {
        configuration = {
          my.theme = lib.mkForce theme;
          my.isThemeSpecialisation = true;
        };
      }) (lib.removeAttrs available [ catalogue.default ]);

      home.activation = {
        themeBaseGeneration = lib.hm.dag.entryAfter [ "themePack" ] ''
          run --quiet sh -c 'echo "$1" > "$2"' _ "$newGenPath" ${lib.escapeShellArg stateDir}/base-generation
        '';

        # A rebuild activates the base (default) theme; re-apply the user's choice.
        themeRestore = lib.hm.dag.entryAfter [ "themeBaseGeneration" "reloadSystemd" "onFilesChange" ] ''
          selected=${lib.escapeShellArg stateDir}/selected
          if [ -f "$selected" ]; then
            themeName="$(cat "$selected")"
            if [ "$themeName" != ${lib.escapeShellArg catalogue.default} ] \
              && [ -x "$newGenPath/specialisation/$themeName/activate" ]; then
              verboseEcho "Restoring theme $themeName"
              run "$newGenPath/specialisation/$themeName/activate"
            fi
          fi
        '';
      };
    })
  ];
}
