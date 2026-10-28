# Builds the theme catalogue (themes/default.nix) once and applies the default
# theme system-wide with Stylix: greeter, console, boot loader, GTK/Qt
# defaults. Per-user switching lives in modules/home/theme.nix, which reads the
# catalogue through `osConfig.my.themes`.
{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  catalogue = config.my.themes;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  options.my.themes = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    internal = true;
    default = import ../../themes {
      inherit pkgs lib;
      base16 = inputs.stylix.inputs.base16.lib { inherit pkgs lib; };
    };
  };

  config.stylix = {
    enable = true;
    homeManagerIntegration.autoImport = true;
    homeManagerIntegration.followSystem = true;
  }
  // catalogue.toStylix catalogue.themes.${catalogue.default};
}
