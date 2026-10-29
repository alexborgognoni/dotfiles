# The patched librepods daemon the Noctalia AirPods plugin talks to (a fork of
# kavishdevar/librepods with a published state file, control verbs for the
# plugin, AirPods Pro 3 support and a --headless mode). Pinned to a commit.
# `librepods-ctl` is the plugin's control tool.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  qt6,
  openssl,
  libpulseaudio,
}:
stdenv.mkDerivation {
  pname = "librepods-daemon";
  version = "0-unstable-2026-08-16";

  src = fetchFromGitHub {
    owner = "harveywuk";
    repo = "librepods";
    rev = "4ed49df0b301ac3e6fba9c81dfbbb6726cc52201";
    hash = "sha256-Ygoqz5lnGMwZkys+Q4c4pyAUI0llvpGZ/ij5E91CkAg=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
    qt6.qttools
  ];
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtconnectivity
    openssl
    libpulseaudio
  ];

  cmakeFlags = [ "-DBUILD_TESTING=OFF" ];

  postInstall = ''
    substituteInPlace $out/share/systemd/user/librepods.service \
      --replace-fail '%h/.local/bin/librepods' "$out/bin/librepods"
  '';

  meta = {
    description = "AirPods daemon for the Noctalia AirPods plugin (patched librepods)";
    homepage = "https://github.com/harveywuk/librepods";
    license = lib.licenses.gpl3Only;
    mainProgram = "librepods";
    platforms = lib.platforms.linux;
  };
}
