# OpenWhispr: voice dictation (Whisper) for the desktop, packaged from the
# upstream AppImage. Update with `nix-update --flake openwhispr`.
{
  lib,
  appimageTools,
  fetchurl,
}:
let
  pname = "openwhispr";
  version = "1.10.4";

  src = fetchurl {
    url = "https://github.com/OpenWhispr/openwhispr/releases/download/v${version}/OpenWhispr-${version}-linux-x86_64.AppImage";
    hash = "sha256-54SUDZioTBpTHXUPyyxILgiFYBn4ZjiwvQzr/I83WHY=";
  };

  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    desktop=$(find ${contents} -maxdepth 1 -name '*.desktop' | head -1)
    install -Dm444 "$desktop" $out/share/applications/openwhispr.desktop
    substituteInPlace $out/share/applications/openwhispr.desktop \
      --replace-quiet 'Exec=AppRun --no-sandbox' 'Exec=openwhispr' \
      --replace-quiet 'Exec=AppRun' 'Exec=openwhispr'
    if [ -d ${contents}/usr/share/icons ]; then
      cp -r ${contents}/usr/share/icons $out/share/
    fi
  '';

  meta = {
    description = "Voice-to-text dictation with Whisper, for the desktop";
    homepage = "https://github.com/OpenWhispr/openwhispr";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "openwhispr";
  };
}
