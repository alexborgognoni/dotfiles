# VLC 3 only runs through XWayland, which Hyprland does not scale (see
# xwayland.force_zero_scaling), so the launcher hands VLC the scale of the
# focused monitor, the one set in the monitor profiles.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Stylix's Kvantum theme without the translucent, shadowed popup frame that
  # shows as a ghost border around VLC's menus under XWayland.
  qtTemplates = inputs.stylix + "/modules/qt";
  kvantumVlc =
    let
      kvconfig = config.lib.stylix.colors {
        template = builtins.readFile (qtTemplates + "/kvconfig.mustache");
        extension = ".kvconfig";
      };
      svg = config.lib.stylix.colors {
        template = builtins.readFile (qtTemplates + "/kvantum.svg.mustache");
        extension = ".svg";
      };
    in
    pkgs.runCommandLocal "base16-kvantum-vlc" { } ''
      directory="$out/share/Kvantum/Base16KvantumVlc"
      mkdir --parents "$directory"
      sed -e 's/^composite=.*/composite=false/' \
          -e 's/^menu_shadow_depth=.*/menu_shadow_depth=0/' \
          -e 's/^popup_blurring=.*/popup_blurring=false/' \
          -e 's/^shadowless_popup=.*/shadowless_popup=true/' \
          ${kvconfig} > "$directory/Base16KvantumVlc.kvconfig"
      cp ${svg} "$directory/Base16KvantumVlc.svg"
    '';

  vlc-scaled = pkgs.writeShellScriptBin "vlc-scaled" ''
    scale="$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '[.[] | select(.focused)][0].scale // 1')"
    QT_SCALE_FACTOR="$scale" exec vlc "$@"
  '';
in
{
  config = lib.mkIf config.my.features.desktop.enable {
    home.packages = [ vlc-scaled ];

    qt.kvantum = lib.mkIf (config.stylix.enable && config.stylix.targets.qt.enable) {
      themes = [ kvantumVlc ];
      settings.Applications.Base16KvantumVlc = [ "vlc" ];
    };

    xdg.dataFile."applications/vlc.desktop".source =
      pkgs.runCommand "vlc.desktop" { } ''
        sed 's|^Exec=[^ ]*|Exec=${vlc-scaled}/bin/vlc-scaled|' \
          ${pkgs.vlc}/share/applications/vlc.desktop > $out
      '';
  };
}
