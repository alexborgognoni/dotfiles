# Overlay: `pkgs.unstable` (latest packages from nixos-unstable) and the
# packages defined in this repository (also exposed as flake `packages`).
{
  inputs,
  # the retreat switch (runtimes.nix); a test passes the other value
  patchedRuntimes ? (import ../runtimes.nix).patched,
}:
final: _prev:
let
  u = final.unstable;
in
{
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    inherit (final) config;
  };

  forgecode = final.callPackage ./forgecode/package.nix { };

  # nixpkgs' bun that can load prebuilt native addons (sharp); plain bun when
  # the runtimes are not patched
  bun-native-libs =
    if patchedRuntimes then u.callPackage ./bun-native-libs/package.nix { } else u.bun;

  # nixpkgs' Python interpreters that load PyPI wheels:
  # { withPackages; python; versions; poetry } (python-native-libs/package.nix)
  pythonNativeLibs =
    if patchedRuntimes then
      u.callPackage ./python-native-libs/package.nix { }
    else
      {
        withPackages = u.python314.withPackages;
        python = u.python314.withPackages (_: [ ]);
        inherit (u) poetry;
        versions = final.runCommand "python-versions" { } ''
          mkdir -p $out/bin
          ln -s ${u.python312}/bin/python3.12 $out/bin/python3.12
          ln -s ${u.python313}/bin/python3.13 $out/bin/python3.13
        '';
      };

  # nixpkgs' Lua and LuaJIT that load prebuilt C modules, and the luarocks of
  # that Lua: { lua; luajit; luarocks } (lua-native-libs/package.nix)
  luaNativeLibs =
    if patchedRuntimes then
      u.callPackage ./lua-native-libs/package.nix { }
    else
      let
        only = import ./only-bin.nix { inherit (final) lib runCommand; };
      in
      {
        lua = only u.lua [
          "lua"
          "luac"
        ];
        luajit = only u.luajit [ "luajit" ];
        inherit (u.lua.pkgs) luarocks;
      };

  # `with-cuda` and `with-gui-libs`: one command with the GPU driver's or the
  # GUI libraries visible, nothing else (with-libs/package.nix)
  withLibs = u.callPackage ./with-libs/package.nix { };
}
