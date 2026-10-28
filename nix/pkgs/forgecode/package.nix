# ForgeCode: AI pair programmer for the terminal. Upstream ships a static musl
# binary; update with `nix-update --flake forgecode` (or bump version + hash).
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "forgecode";
  version = "2.14.0";

  src = fetchurl {
    url = "https://github.com/antinomyhq/forge/releases/download/v${finalAttrs.version}/forge-x86_64-unknown-linux-musl";
    hash = "sha256-ZIMvgovwiWEyLjAiQ/NS7nwn6I12+XJXSjYox7cMsb4=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/forge
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/forge --version | grep -q ${finalAttrs.version}
  '';

  meta = {
    description = "AI pair programmer for the terminal";
    homepage = "https://forgecode.dev";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "forge";
  };
})
