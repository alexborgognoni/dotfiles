# Overlay: `pkgs.unstable` (latest packages from nixos-unstable) and the
# packages defined in this repository (also exposed as flake `packages`).
{ inputs }:
final: _prev: {
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    inherit (final) config;
  };

  forgecode = final.callPackage ./forgecode/package.nix { };

  # nixpkgs' bun that can load native addons needing libstdc++ (sharp)
  bun-libstdcxx = final.unstable.callPackage ./bun-libstdcxx/package.nix { };
}
