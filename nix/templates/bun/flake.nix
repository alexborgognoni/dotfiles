# Dev shell with an exact Bun, for a project that pins one (Daisy: mise.toml and
# a strict check of Bun.version) on a host without mise, i.e. NixOS. nixpkgs has
# one Bun version; this builds the official release of the version below, with
# the libraries prebuilt addons such as sharp need (libstdc++, libz) carried by
# the executable, as pkgs/bun-native-libs does (docs/NATIVE-CODE.md).
#
# A new version: change `version` and `hash`. The hash of the release zip:
#   nix-prefetch-url --type sha256 \
#     https://github.com/oven-sh/bun/releases/download/bun-vVERSION/bun-linux-x64-baseline.zip \
#     | xargs nix hash convert --hash-algo sha256 --to sri
{
  description = "Dev shell with an exact Bun";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      version = "1.4.2";
      hash = "sha256-xngEDxT+BEDrg503y9DOTAUaMtpygGrJfeamqra/co8=";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      bun = pkgs.stdenvNoCC.mkDerivation {
        pname = "bun";
        inherit version;
        src = pkgs.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64-baseline.zip";
          inherit hash;
        };
        nativeBuildInputs = [
          pkgs.unzip
          pkgs.autoPatchelfHook
          pkgs.patchelf
        ];
        buildInputs = [
          pkgs.stdenv.cc.cc.lib
          pkgs.zlib
          pkgs.openssl
        ];
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          install -Dm755 ./bun $out/bin/bun
          ln -s $out/bin/bun $out/bin/bunx
        '';
        # autoPatchelf adds their directories to the RUNPATH once they are needed
        preFixup = ''
          patchelf --add-needed libstdc++.so.6 --add-needed libz.so.1 $out/bin/bun
        '';
      };
    in
    {
      packages.${system}.bun = bun;
      devShells.${system}.default = pkgs.mkShell { packages = [ bun ]; };
    };
}
