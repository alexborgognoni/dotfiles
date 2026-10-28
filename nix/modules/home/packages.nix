# Package groups for standalone Home Manager (packages/default.nix). On NixOS
# the groups are installed by modules/nixos/packages.nix instead, so this
# stays empty there.
{
  config,
  lib,
  packageGroups,
  ...
}:
{
  options.my.packages.groups = lib.mkOption {
    type = lib.types.listOf (
      lib.types.enum [
        "cli"
        "gui"
        "browsers"
      ]
    );
    default = [ ];
    example = [
      "cli"
      "gui"
    ];
    description = "Package groups from packages/default.nix to install with Home Manager.";
  };

  config.home.packages = lib.concatMap (g: packageGroups.${g}) config.my.packages.groups;
}
