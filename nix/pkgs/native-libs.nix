# The libraries that prebuilt native code (npm addons, PyPI wheels) expects the
# system to provide, and that a Nix-built runtime cannot find by itself: its
# glibc searches only the Nix store, and a library with its own RUNPATH (every
# wheel) ignores the executable's search path. So the runtime carries them as
# needed libraries (a library loaded by name is reused by every later dlopen),
# the way nodejs carries libstdc++ and libz. Used by bun-native-libs and
# python-native-libs, called with the package set of the runtime.
#
# Extend the list when a wheel or addon fails with
#   "<name>.so.N: cannot open shared object file"
# (nix/docs/NATIVE-CODE.md). Only libraries that wheels do not vendor belong
# here (numpy, pandas, scipy, opencv, onnxruntime: libz; everything C++:
# libstdc++); GUI and GPU libraries (libGL, libX11) belong in a dev shell.
{
  lib,
  stdenv,
  zlib,
}:
rec {
  packages = [
    stdenv.cc.cc.lib
    zlib
  ];
  sonames = [
    "libstdc++.so.6"
    "libz.so.1"
  ];
  # for patchelf
  needed = lib.concatMapStringsSep " " (s: "--add-needed ${s}") sonames;
  rpath = lib.makeLibraryPath packages;
}
