# Tool versions of projects that pin them in mise.toml (the team's source of
# truth, e.g. Daisy): `mise install` in the checkout. mise downloads the tools'
# official binaries, which run on a distribution's own loader (Ubuntu) but are
# unpatched executables on NixOS, where they would need nix-ld; so only a host
# that can run foreign binaries has it (my.foreignBinaries: Ubuntu, or NixOS
# when the runtimes are not patched). On NixOS such a project gets a Nix dev shell
# instead (templates/bun pins an exact Bun; docs/NATIVE-CODE.md).
#
# One source per context: inside a project with a mise.toml, its tools (mise's
# prompt hook puts them first on PATH); everywhere else, Nix's. mise's own
# default would also put its shims directory first on PATH, so that a shim
# answered for bun, uv, ... in every directory and shadowed Nix's; a script or
# an IDE that has no prompt hook uses `mise exec -- <command>`.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.foreignBinaries {
    programs.mise = {
      enable = true;
      package = pkgs.unstable.mise;
      globalConfig.settings.activate_shims = false;
    };
  };
}
