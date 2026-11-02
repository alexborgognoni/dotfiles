# Overlay: `pkgs.unstable` (latest packages from nixos-unstable) and the
# packages defined in this repository (also exposed as flake `packages`).
{ inputs }:
final: _prev: {
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    inherit (final) config;
  };

  forgecode = final.callPackage ./forgecode/package.nix { };

  # nixpkgs' bun that can load prebuilt native addons (sharp)
  bun-native-libs = final.unstable.callPackage ./bun-native-libs/package.nix { };

  # nixpkgs' Python interpreters that load PyPI wheels:
  # { withPackages; python; versions } (python-native-libs/package.nix)
  pythonNativeLibs = final.unstable.callPackage ./python-native-libs/package.nix { };

  # nixpkgs' Lua and LuaJIT that load prebuilt C modules, and the luarocks of
  # that Lua: { lua; luajit; luarocks } (lua-native-libs/package.nix)
  luaNativeLibs = final.unstable.callPackage ./lua-native-libs/package.nix { };
}
