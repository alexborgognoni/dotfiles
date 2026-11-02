# nixpkgs' Lua and LuaJIT that load prebuilt C modules (native-libs.nix).
#
# A C module that was not built by Nix (a binary rock from luarocks.org, a
# library used through LuaJIT's ffi) expects libstdc++.so.6 and libz.so.1 in
# the standard library path, which a Nix-built interpreter cannot see:
# `package.loadlib` fails with "libz.so.1: cannot open shared object file". The
# interpreters carry the libraries as needed libraries instead, as
# pkgs/python-native-libs does for Python, without nix-ld or LD_LIBRARY_PATH.
#
# luarocks is the one built for the same Lua: nixpkgs' default luarocks is
# built for Lua 5.2 and installs rocks that the other versions cannot load.
#
# Called with the unstable package set.
{
  lib,
  runCommand,
  patchelf,
  stdenv,
  zlib,
  lua,
  luajit,
}:
let
  native = import ../native-libs.nix { inherit lib stdenv zlib; };
  patchedRuntime = import ../patched-runtime.nix { inherit runCommand patchelf; };
  # only these executables, so that the two do not both provide `lua`; and
  # ahead of the plain lua that luarocks pulls into a profile as a dependency
  only =
    pkg: names:
    lib.hiPrio (
      runCommand "${pkg.name}-bin" { } ''
        mkdir -p $out/bin
        ${lib.concatMapStringsSep "\n" (n: "ln -s ${pkg}/bin/${n} $out/bin/${n}") names}
      ''
    );
in
{
  lua = only (patchedRuntime native lua [ "lua" ]) [
    "lua"
    "luac"
  ];
  luajit = only (patchedRuntime native luajit [ "luajit" ]) [ "luajit" ];
  # for the Lua above
  inherit (lua.pkgs) luarocks;
}
