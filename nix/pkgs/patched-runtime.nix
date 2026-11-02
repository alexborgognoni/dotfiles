# A copy of `pkg` in which the given executables need the libraries of
# native-libs.nix: the executable is copied and patched (patchelf), everything
# else is linked to the original, so nothing is rebuilt and the runtime finds
# its standard library next to the copy. Used by python-native-libs and
# lua-native-libs; bun is patched in its own build (bun-native-libs).
{ runCommand, patchelf }:
native: pkg: binaries:
runCommand "${pkg.name}-native-libs"
  {
    nativeBuildInputs = [ patchelf ];
    inherit (pkg) meta;
  }
  ''
    mkdir -p $out/bin
    for entry in ${pkg}/*; do
      [ "$(basename "$entry")" = bin ] || ln -s "$entry" "$out/$(basename "$entry")"
    done
    for entry in ${pkg}/bin/*; do
      ln -s "$entry" "$out/bin/$(basename "$entry")"
    done
    for binary in ${toString binaries}; do
      # a real file, so that the runtime finds its prefix next to it
      rm "$out/bin/$binary"
      cp -L ${pkg}/bin/$binary "$out/bin/$binary"
      chmod u+w "$out/bin/$binary"
      patchelf --add-rpath ${native.rpath} ${native.needed} "$out/bin/$binary"
    done
  ''
