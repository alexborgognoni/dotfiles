# The `theme` command (picker, apply, preview, accent, wallpaper). The shell
# script is ./scripts/theme.sh; the values it needs are filled in here.
{
  config,
  lib,
  pkgs,
  catalogue,
  available,
  stateDir,
}:
let
  features = config.my.features;

  # theme wallpaper rotate on|off|toggle -> prints the new state
  rotateScript = pkgs.writers.writePython3 "theme-wallpaper-rotate" {
    libraries = [ pkgs.python3Packages.tomli-w ];
  } (builtins.readFile ./scripts/wallpaper-rotate.py);
  # theme apps: how every application follows the theme (themes/apps.nix)
  appsTable = pkgs.writeText "theme-apps" (
    "APPLICATION\tHOW\tDETAIL\n"
    + lib.concatStrings (
      lib.mapAttrsToList (
        name: e:
        "${name}\t${e.how}\t${e.file or e.target or e.toolkit or ""}${
          lib.optionalString (e ? note)
            "${if e ? file || e ? target || e ? toolkit then " - " else ""}${e.note}"
        }\n"
      ) (import ../../../themes/apps.nix).apps
    )
  );
in
pkgs.writeShellApplication {
  name = "theme";
  runtimeInputs =
    with pkgs;
    [
      coreutils
      util-linux
      gnugrep
      procps
      findutils
      fzf
      libnotify
      tmux
    ]
    # Explicit, so reloads also work from the activation service's bare PATH.
    ++ lib.optional features.gui.enable config.programs.kitty.package
    ++ lib.optionals features.desktop.enable [
      pkgs.unstable.hyprland
      config.programs.noctalia.package
    ];
  text =
    lib.replaceStrings
      [ "@state@" "@default@" "@themes@" "@rotate@" "@apps@" ]
      [
        (lib.escapeShellArg stateDir)
        (lib.escapeShellArg catalogue.default)
        (lib.escapeShellArgs (lib.attrNames available))
        "${rotateScript}"
        "${appsTable}"
      ]
      (builtins.readFile ./scripts/theme.sh);
}
