# Go dev shell, for system libraries cgo links against, or another Go version
# for a project without a `toolchain` line in go.mod (with one, Go downloads
# that exact version by itself: the official toolchains are static binaries, so
# that works on every host). Nix's compiler sees only what Nix provides, never
# the distribution's /usr/include and /usr/lib: a C library cgo links against is
# named in buildInputs (docs/NATIVE-CODE.md).
{
  description = "Go dev shell";

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
            packages = [
              pkgs.go # a specific version: pkgs.go_1_25, ...
              pkgs.gopls
            ];
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = with pkgs; [
              openssl
              zlib
            ];
          };
        }
      );
    };
}
