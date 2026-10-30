# Entra ID single sign-on for browsers on Linux (Siemens' linux-entra-sso):
# the native messaging host the browser extension talks to; it asks the
# Microsoft Identity Broker (corporate, from apt) over D-Bus. Runs on its own
# Python with pydbus and PyGObject. The extension and the host must be the same
# version: the Chrome extension updates itself from the Web Store; the Firefox
# one is the signed .xpi of the same release (passthru.firefoxExtension).
#
# Update: bump `version`, then `hash` (the source) and `xpiHash`
#   nix store prefetch-file https://github.com/siemens/linux-entra-sso/releases/download/v<version>/linux_entra_sso-<version>.xpi
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  runCommand,
  jq,
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
  version = "1.13.0";
  xpiHash = "sha256-7tVfNgUN9TiGwoweO76iJ0V5CUvzr2qELye/vEo31tw=";
  # Chrome extensions allowed to use the host
  chromeExtensions = [
    "hplengpodecdmlndbnahhjipadllfnfo"
    "jlnfnnolkbjieggibinobhkjdfbpcohn"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "linux-entra-sso";
  inherit version;

  src = fetchFromGitHub {
    owner = "siemens";
    repo = "linux-entra-sso";
    tag = "v${version}";
    hash = "sha256-zkdS7dsIUgIoj6g+to1++K655nUXyE6uxkx6uIoHh6w=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 linux-entra-sso.py $out/libexec/linux-entra-sso
    substituteInPlace $out/libexec/linux-entra-sso \
      --replace-fail '#!/usr/bin/env python3' '#!${python}/bin/python3' \
      --replace-fail 'LINUX_ENTRA_SSO_VERSION = "0.0.0-dev"' 'LINUX_ENTRA_SSO_VERSION = "${version}"'
    # The browser's own LD_LIBRARY_PATH (Nix's Chrome sets one, possibly from
    # another nixpkgs) would load mismatched libraries into this Python.
    wrapProgram $out/libexec/linux-entra-sso \
      --unset LD_LIBRARY_PATH \
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

    # Firefox (and Thunderbird) look the host up by this path in the wrapped
    # browser (Home Manager: programs.firefox.nativeMessagingHosts)
    mkdir -p $out/lib/mozilla/native-messaging-hosts
    cat > $out/lib/mozilla/native-messaging-hosts/linux_entra_sso.json <<EOF
    ${builtins.toJSON {
      name = "linux_entra_sso";
      description = "Entra ID SSO via Microsoft Identity Broker";
      path = "@out@/libexec/linux-entra-sso";
      type = "stdio";
      allowed_extensions = [
        "linux-entra-sso@example.com"
        "@linux-entra-sso.tb"
      ];
    }}
    EOF
    substituteInPlace $out/lib/mozilla/native-messaging-hosts/linux_entra_sso.json --replace-fail '@out@' "$out"
    runHook postInstall
  '';

  # The host starts without a D-Bus session or a broker: this proves that the
  # wrapper, the Python and its GObject libraries work, and that the manifests
  # are valid and point at the host
  doInstallCheck = true;
  nativeInstallCheckInputs = [ jq ];
  installCheckPhase = ''
    runHook preInstallCheck
    [ "$($out/libexec/linux-entra-sso --version)" = "${version}" ]
    for manifest in $out/share/linux-entra-sso/chrome/linux_entra_sso.json $out/lib/mozilla/native-messaging-hosts/linux_entra_sso.json; do
      [ "$(jq -r .path $manifest)" = "$out/libexec/linux-entra-sso" ]
    done
    runHook postInstallCheck
  '';

  # The signed Firefox extension of this release, as a package for Home
  # Manager (programs.firefox.profiles.<name>.extensions.packages)
  passthru.firefoxExtension =
    let
      addonId = "linux-entra-sso@example.com";
    in
    runCommand "linux-entra-sso-firefox-${version}"
      {
        passthru = { inherit addonId; };
        meta = {
          description = "Entra ID SSO via Microsoft Identity Broker (Firefox extension)";
          homepage = "https://github.com/siemens/linux-entra-sso";
          license = lib.licenses.mpl20;
        };
      }
      ''
        install -Dm644 ${
          fetchurl {
            url = "https://github.com/siemens/linux-entra-sso/releases/download/v${version}/linux_entra_sso-${version}.xpi";
            hash = xpiHash;
          }
        } "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/${addonId}.xpi"
      '';

  meta = {
    description = "Entra ID SSO via Microsoft Identity Broker on Linux (browser host tooling)";
    homepage = "https://github.com/siemens/linux-entra-sso";
    license = lib.licenses.mpl20;
    mainProgram = "linux-entra-sso";
  };
}
