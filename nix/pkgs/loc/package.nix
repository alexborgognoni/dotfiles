# loc (cgag/loc): fast line-of-code counter in Rust (not in nixpkgs).
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "loc";
  version = "0.5.0-unstable-2022-02-20";

  src = fetchFromGitHub {
    owner = "cgag";
    repo = "loc";
    rev = "1e0c7f434ddfd51439e1d4eb126f31b7a04229d9";
    hash = "sha256-GYnXoiYAePf6paExmeDF3XDZ8mSF5hmmXkTvxSpOj+U=";
  };

  cargoHash = "sha256-3ebajlV0ONO2ggMCtfwWLnOlGDi7dx1iL+FpyG8OSI0=";

  meta = {
    description = "Count lines of code quickly";
    homepage = "https://github.com/cgag/loc";
    license = lib.licenses.mit;
    mainProgram = "loc";
    platforms = lib.platforms.unix;
  };
}
