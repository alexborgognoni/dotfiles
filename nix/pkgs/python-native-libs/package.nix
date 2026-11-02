# nixpkgs' Python interpreters that can load PyPI wheels (native-libs.nix).
#
# A wheel (numpy, pandas, pydantic-core, grpcio, ...) is prebuilt native code
# that expects libstdc++.so.6 and libz.so.1 in the standard library path. A
# Nix-built interpreter uses Nix's glibc, which only searches the Nix store,
# and python itself does not need them: `import numpy` fails with ImportError.
# nodejs avoids this because it lists them as needed libraries; this does the
# same for Python (as pkgs/bun-native-libs does for bun). It needs no nix-ld, no
# LD_LIBRARY_PATH (which would reach every child process, and breaks the
# distribution's own programs on Ubuntu) and no rebuild of Python: only the
# interpreter binary is copied and patched; everything else is linked to the
# original, so a virtualenv created from it (venv, uv, poetry) finds the same
# standard library and its wheels load.
#
# Called with the unstable package set (the libraries match Python's glibc).
{
  lib,
  runCommand,
  patchelf,
  stdenv,
  zlib,
  python312,
  python313,
  python314,
}:
let
  native = import ../native-libs.nix { inherit lib stdenv zlib; };

  patchedRuntime = import ../patched-runtime.nix { inherit runCommand patchelf; };

  # `python` with the libraries needed by the interpreter: same attributes as
  # `python`, so python.buildEnv (the env builder of withPackages) takes it.
  patch =
    python:
    let
      patched = patchedRuntime native python [ python.executable ];
    in
    patched
    // {
      inherit (python)
        executable
        sitePackages
        pythonVersion
        passthru
        ;
      interpreter = "${patched}/bin/${python.executable}";
    };

  # python.withPackages, on the patched interpreter
  withPackagesOf =
    python: f:
    python.buildEnv.override {
      python = patch python;
      extraLibs = f python.pkgs;
    };
in
{
  # python3 (3.14) with packages from nixpkgs; wheels in virtualenvs load
  withPackages = withPackagesOf python314;
  python = withPackagesOf python314 (_: [ ]);

  # python3.12 and python3.13 on PATH for projects that need an older Python
  # (only the versioned names: python3 stays the 3.14 above)
  versions =
    let
      env = python: withPackagesOf python (_: [ ]);
    in
    runCommand "python-versions-native-libs" { } ''
      mkdir -p $out/bin
      ${lib.concatMapStringsSep "\n"
        (python: ''
          ln -s ${env python}/bin/${python.executable} $out/bin/${python.executable}
        '')
        [
          python312
          python313
        ]
      }
    '';
}
