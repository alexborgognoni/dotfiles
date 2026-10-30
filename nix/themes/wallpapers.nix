# Wallpaper helpers: recoloring to a theme palette and listing image files.
{ pkgs, lib }:
let
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
in
{
  inherit recolor imageFiles;
}
