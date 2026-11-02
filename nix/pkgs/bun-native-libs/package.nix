# nixpkgs' bun with the libraries prebuilt native code expects (native-libs.nix).
#
# Upstream bun links its C++ runtime statically, so after autoPatchelf nothing
# in the process provides libstdc++.so.6 or libz.so.1, and prebuilt Node-API
# addons that need them (sharp, ...) fail with ERR_DLOPEN_FAILED, while nodejs,
# which lists them as needed libraries, loads them.
# https://github.com/NixOS/nixpkgs/issues/573990
#
# Adding the libraries to the executable, and not to LD_LIBRARY_PATH, keeps
# them out of every child process bun starts (git, docker, ...). Called with
# the unstable package set so the libraries match bun's glibc.
#
# TODO(drop): remove this package once nixpkgs fixes
# https://github.com/NixOS/nixpkgs/issues/573990 (use `pkgs.unstable.bun` in
# packages/default.nix and claude.nix again). The check
# `bun-upstream-still-broken` fails when plain nixpkgs bun loads the probe, i.e.
# when that happens (docs/NATIVE-CODE.md).
{
  lib,
  bun,
  patchelf,
  stdenv,
  zlib,
}:
let
  native = import ../native-libs.nix { inherit lib stdenv zlib; };
in
bun.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [ patchelf ];
  # autoPatchelf adds their directories to the RUNPATH once they are needed
  buildInputs = old.buildInputs ++ native.packages;
  preFixup = (old.preFixup or "") + ''
    patchelf ${native.needed} $out/bin/bun
  '';
})
