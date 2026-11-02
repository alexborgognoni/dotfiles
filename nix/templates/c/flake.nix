# C/C++ dev shell. Nix's compiler sees only what Nix provides, never the
# distribution's /usr/include and /usr/lib: a library the build links against
# is named in buildInputs (pkg-config and the headers follow from it). Find a
# library's name with `nix search nixpkgs <name>` (docs/NATIVE-CODE.md).
{
  description = "C/C++ dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              cmake
              gnumake
              pkg-config
            ];
            buildInputs = with pkgs; [
              openssl
              zlib
            ];
          };
        }
      );
    };
}
