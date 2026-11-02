# Run one command with a narrow set of extra libraries visible to it.
#
# Some prebuilt code does not need a library to start but dlopens it later by
# name: a CUDA wheel (torch) asks for the NVIDIA driver's libcuda.so.1, a GUI
# wheel (opencv-python, PyQt) for libGL and libX11. A Nix-built runtime cannot
# find them (pkgs/native-libs.nix has the ones every module needs, loaded at
# start). Putting these in the runtime would load a graphics stack into every
# process, and a global LD_LIBRARY_PATH reaches every child: on Ubuntu a Nix
# libGL needs a newer glibc than the host's and breaks host programs. So: an
# explicit wrapper, per command, nothing else sees it.
#
#   with-cuda python train.py        torch.cuda.is_available() is True
#   with-gui-libs python app.py      import cv2 (non-headless), PyQt
#
# with-cuda exposes only the driver's compute libraries (libcuda, NVML, the PTX
# JIT compiler, nvvm) from /run/opengl-driver/lib, which both NixOS (graphics)
# and Ubuntu (targets.genericLinux.gpu) provide, version-matched to the kernel
# driver. Prefer the headless variant of a wheel (opencv-python-headless) when
# there is one. WITH_LIBS_DRIVER_DIR points the wrappers elsewhere (tests).
{
  lib,
  writeShellApplication,
  libglvnd,
  libx11,
  libxcb,
  libxext,
  libxrender,
  libsm,
  libice,
  glib,
  fontconfig,
  freetype,
  libxkbcommon,
  dbus,
}:
let
  usage = name: ''
    [ "$#" -gt 0 ] || { echo "usage: ${name} <command> [args...]" >&2; exit 2; }
  '';
in
{
  with-cuda = writeShellApplication {
    name = "with-cuda";
    text = ''
      ${usage "with-cuda"}
      driver="''${WITH_LIBS_DRIVER_DIR:-/run/opengl-driver/lib}"
      dir="''${XDG_CACHE_HOME:-$HOME/.cache}/with-cuda"
      mkdir -p "$dir"
      found=0
      for lib in libcuda.so.1 libnvidia-ml.so.1 libnvidia-ptxjitcompiler.so.1 libnvidia-nvvm.so.4; do
        if [ -e "$driver/$lib" ]; then
          ln -sfn "$driver/$lib" "$dir/$lib"
          found=1
        else
          rm -f "$dir/$lib"
        fi
      done
      [ "$found" = 1 ] || echo "with-cuda: no NVIDIA driver libraries in $driver" >&2
      exec env LD_LIBRARY_PATH="$dir''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$@"
    '';
  };

  with-gui-libs = writeShellApplication {
    name = "with-gui-libs";
    text = ''
      ${usage "with-gui-libs"}
      driver="''${WITH_LIBS_DRIVER_DIR:-/run/opengl-driver/lib}"
      libs="${
        lib.makeLibraryPath [
          libglvnd
          libx11
          libxcb
          libxext
          libxrender
          libsm
          libice
          glib
          fontconfig
          freetype
          libxkbcommon
          dbus
        ]
      }"
      # the GL vendor libraries (libGLX_nvidia, ...) come with the graphics driver
      exec env LD_LIBRARY_PATH="$libs:$driver''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$@"
    '';
  };
}
