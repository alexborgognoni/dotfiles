# LibrePods (AirPods controls), the Rust rewrite (upstream branch linux/rust)
# at a pinned commit, with local changes (local.patch: activation socket for
# single-instance, window fixes). `librepods` is a single-instance launcher:
# a second start shows the running instance's window.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  writeShellApplication,
  symlinkJoin,
  dbus,
  libpulseaudio,
  wayland,
  libxkbcommon,
  vulkan-loader,
  libGL,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  util-linux,
  netcat-openbsd,
  libnotify,
}:
let
  unwrapped = rustPlatform.buildRustPackage {
    pname = "librepods";
    version = "0.1.0-unstable-672e65a";

    src = fetchFromGitHub {
      owner = "librepods-org";
      repo = "librepods";
      rev = "672e65ad36eebf21ff1c1a508066f9197ee56d17";
      hash = "sha256-EuIYvBqBtpgutVqPOLIO3E9OhVzQ5q5TDoz/F+9MHEE=";
    };
    sourceRoot = "source/linux-rust";

    # local.patch is relative to the repository root (a/linux-rust/...)
    patches = [ ./local.patch ];
    patchFlags = [ "-p2" ];

    cargoHash = "sha256-17dE+oYvECU4f1SL6LHS95sXEea/Z0VgTPQ4u6TZTic=";

    nativeBuildInputs = [
      pkg-config
    ];
    buildInputs = [
      dbus
      libpulseaudio
    ];

    # winit and wgpu load these at runtime
    postFixup = ''
      patchelf --add-rpath ${
        lib.makeLibraryPath [
          wayland
          libxkbcommon
          vulkan-loader
          libGL
          libx11
          libxcursor
          libxi
          libxrandr
        ]
      } $out/bin/librepods
      install -Dm644 assets/me.kavishdevar.librepods.desktop $out/share/applications/me.kavishdevar.librepods.desktop
      install -Dm644 assets/icon.png $out/share/icons/hicolor/512x512/apps/me.kavishdevar.librepods.png
    '';

    meta.mainProgram = "librepods";
  };

  launcher = writeShellApplication {
    name = "librepods";
    runtimeInputs = [
      util-linux
      netcat-openbsd
      libnotify
    ];
    text = ''
      # First launch holds the lock and runs LibrePods; later launches ask the
      # running instance (activation socket) to show its window.
      lock="''${XDG_RUNTIME_DIR:-/tmp}/librepods.instance.lock"
      exec 9>"$lock"
      if ! flock -n 9; then
        sock="''${XDG_RUNTIME_DIR:-/tmp}/librepods-activate.sock"
        if [ -S "$sock" ] && printf 'open\n' | timeout 2 nc -U -N "$sock" >/dev/null 2>&1; then
          exit 0
        fi
        notify-send -a LibrePods "LibrePods" "Already running in the system tray."
        exit 0
      fi
      exec ${unwrapped}/bin/librepods "$@"
    '';
  };
in
# `librepods` = the launcher; app entry and icon from the build
symlinkJoin {
  name = "librepods-${unwrapped.version}";
  paths = [
    launcher
    unwrapped
  ];
  postBuild = ''
    # the launcher's bin/librepods wins over the program's
    rm "$out/bin/librepods"
    ln -s ${launcher}/bin/librepods "$out/bin/librepods"
  '';
  passthru = { inherit unwrapped; };
  meta.mainProgram = "librepods";
}
