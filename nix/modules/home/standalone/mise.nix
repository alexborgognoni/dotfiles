# Tool versions of projects that pin them in mise.toml (the team's source of
# truth, e.g. Daisy): `mise install` in the checkout. mise downloads the
# tools' official binaries, which run on a distribution's own loader (Ubuntu)
# but are unpatched executables on NixOS, where they would need nix-ld; so
# only standalone Home Manager has it. On NixOS such a project gets a Nix dev
# shell instead (docs/NATIVE-CODE.md).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.standalone {
    programs.mise = {
      enable = true;
      package = pkgs.unstable.mise;
    };
  };
}
