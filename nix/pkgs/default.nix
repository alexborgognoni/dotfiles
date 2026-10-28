# Overlay: `pkgs.unstable` (latest packages from nixos-unstable) and the
# packages defined in this repository (also exposed as flake `packages`).
{ inputs }:
final: prev: {
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    config = final.config;
  };

  forgecode = final.callPackage ./forgecode/package.nix { };
  openwhispr = final.callPackage ./openwhispr/package.nix { };
}
