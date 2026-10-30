# Builds the theme catalogue (themes/) once and applies the default
# theme system-wide with Stylix: greeter, console, boot loader, GTK/Qt
# defaults. Per-user switching lives in modules/home/theme/, which gets the
# catalogue as a special argument (modules/nixos/home-manager.nix).
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
    # The Home Manager modules import and configure Stylix themselves, so
    # they work the same without NixOS.
    homeManagerIntegration.autoImport = false;
  }
  // catalogue.toStylix catalogue.themes.${catalogue.default};
}
