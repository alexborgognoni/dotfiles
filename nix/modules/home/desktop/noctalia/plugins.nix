# Noctalia plugins, each pinned to the newest revision the packaged Noctalia
# (plugin API 39 in 5.4) can run, and offered to Noctalia as one read-only path
# source: nothing is fetched, installed or updated at runtime. A plugin
# is enabled per host with my.desktop.noctalia.plugins; its tools come with it.
#
# To pin another revision, take it from the `[[plugin.release]]` rows of
# catalog.toml in the source repository (the newest one whose plugin_api is
# at most the shell's), then `nix build` once with a wrong hash for the new one.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.noctalia.plugins;

  catalog = import ./plugin-catalog.nix { inherit config pkgs; };

  enabled = lib.genAttrs cfg (name: catalog.${name});

  # A path source is a directory of plugin directories
  plugins = pkgs.runCommand "noctalia-plugins" { } ''
    mkdir -p $out
    ${lib.concatStrings (
      lib.mapAttrsToList (name: p: ''
        cp -r ${p.src}/${name} $out/${name}
        chmod -R u+w $out/${name}
      '') enabled
    )}
    ${lib.concatStrings (
      lib.mapAttrsToList (
        name: p:
        lib.optionalString (p ? patch) ''
          (cd $out && ${p.patch})
        ''
      ) enabled
    )}
  '';
in
{
  options.my.desktop.noctalia.plugins = lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames catalog));
    default = [ ];
    description = "Pinned Noctalia plugins to enable, with the tools they call.";
  };

  config = lib.mkIf (cfg != [ ] && config.my.features.desktop.enable) {
    home.packages = lib.concatMap (p: p.packages or [ ]) (lib.attrValues enabled);

    programs.noctalia.settings = {
      plugins = {
        enabled = lib.mapAttrsToList (_: p: p.id) enabled;
        auto_update = "none";
        source = [
          {
            name = "pinned";
            kind = "path";
            location = "${plugins}";
            enabled = true;
          }
        ];
      };

      # Panels float, like the shell's own (see default.nix): an attached
      # panel inherits the transparent bar's background. The keys are
      # <panel id>_placement / _position / _open_near_click.
      plugin_settings = lib.mapAttrs' (
        _: p:
        lib.nameValuePair p.id (
          lib.foldl' (
            acc: panel:
            acc
            // {
              "${panel}_placement" = "floating";
              "${panel}_position" = "auto";
              "${panel}_open_near_click" = true;
            }
          ) { } (p.panels or [ ])
          // p.settings or { }
        )
      ) enabled;

      widget = lib.foldl' lib.recursiveUpdate { } (map (p: p.widget or { }) (lib.attrValues enabled));
    };
  };
}
