# Entra ID single sign-on for browsers on Linux (Siemens' linux-entra-sso):
# the native messaging host the browser extension talks to; it asks the
# Microsoft Identity Broker (corporate, from apt) over D-Bus. Pinned to the
# commit that was installed by hand before (v1.7.1-1-g9a92ec3), running on
# its own Python with pydbus and PyGObject.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
  glib,
  gobject-introspection,
}:
let
  python = python3.withPackages (ps: [
    ps.pygobject3
    ps.pydbus
  ]);
  version = "1.7.1-1-g9a92ec3";
  # Chrome extensions allowed to use the host (as in the previous manifest)
  chromeExtensions = [
    "hplengpodecdmlndbnahhjipadllfnfo"
    "jlnfnnolkbjieggibinobhkjdfbpcohn"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "linux-entra-sso";
  version = "1.7.1-unstable-9a92ec3";

  src = fetchFromGitHub {
    owner = "siemens";
    repo = "linux-entra-sso";
    rev = "9a92ec39b5f3d1c32d454ee6e1dd66536a2336d7";
    hash = "sha256-CeorIRPhckd+jX6O+RpFNpRQSqdBsju14Cy07uvmIdA=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 linux-entra-sso.py $out/libexec/linux-entra-sso
    substituteInPlace $out/libexec/linux-entra-sso \
      --replace-fail '#!/usr/bin/env python3' '#!${python}/bin/python3' \
      --replace-fail 'LINUX_ENTRA_SSO_VERSION = "0.0.0-dev"' 'LINUX_ENTRA_SSO_VERSION = "${version}"'
    wrapProgram $out/libexec/linux-entra-sso \
      --prefix GI_TYPELIB_PATH : ${
        lib.makeSearchPath "lib/girepository-1.0" [
          glib.out
          gobject-introspection
        ]
      }

    mkdir -p $out/share/linux-entra-sso/chrome
    cat > $out/share/linux-entra-sso/chrome/linux_entra_sso.json <<EOF
    ${builtins.toJSON {
      name = "linux_entra_sso";
      description = "Entra ID SSO via Microsoft Identity Broker";
      path = "@out@/libexec/linux-entra-sso";
      type = "stdio";
      allowed_origins = map (id: "chrome-extension://${id}/") chromeExtensions;
    }}
    EOF
    substituteInPlace $out/share/linux-entra-sso/chrome/linux_entra_sso.json --replace-fail '@out@' "$out"
    runHook postInstall
  '';

  meta = {
    description = "Entra ID SSO via Microsoft Identity Broker on Linux (browser host tooling)";
    homepage = "https://github.com/siemens/linux-entra-sso";
    license = lib.licenses.mpl20;
    mainProgram = "linux-entra-sso";
  };
}
