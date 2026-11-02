# nixpkgs' bun with libstdc++ as a needed library of the executable.
#
# Upstream bun links its C++ runtime statically, so after autoPatchelf nothing
# in the process provides libstdc++.so.6 and prebuilt Node-API addons that
# need it (sharp, ...) fail with ERR_DLOPEN_FAILED, while nodejs, which lists
# libstdc++ as a needed library, loads them.
# https://github.com/NixOS/nixpkgs/issues/573990
#
# Adding the library to the executable, and not to LD_LIBRARY_PATH, keeps it
# out of every child process bun starts (git, docker, ...). Called with the
# unstable package set so libstdc++ matches bun's glibc. Drop this package once
# nixpkgs fixes the issue.
{
  bun,
  patchelf,
  stdenv,
}:
bun.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [ patchelf ];
  # autoPatchelf adds this directory to the RUNPATH once libstdc++.so.6 is needed
  buildInputs = old.buildInputs ++ [ stdenv.cc.cc.lib ];
  preFixup = (old.preFixup or "") + ''
    patchelf --add-needed libstdc++.so.6 $out/bin/bun
  '';
})
