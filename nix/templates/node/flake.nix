# Node/Bun dev shell for browser automation: Playwright's browsers from Nix,
# built for Nix, so nothing downloads an unpatched browser (which needs nix-ld
# and the distribution's libraries on NixOS).
#
# A Playwright browser is tied to the exact version of @playwright/test: the
# revision it asks for (chromium_headless_shell-1228 for 1.61.1) must exist.
# nixpkgs has one version only, so the version comes from
# playwright-web-flake, which tags one commit per Playwright release: set the
# tag in `inputs.playwright.url` to the version in the project's package.json
# (`bun pm ls @playwright/test`). A mismatch says "Executable doesn't exist at
# .../chromium_headless_shell-NNNN".
#
# Puppeteer: PUPPETEER_SKIP_DOWNLOAD=1 and PUPPETEER_EXECUTABLE_PATH to
# `${pkgs.chromium}/bin/chromium`. Test with Chrome or Edge (`channel:
# "chrome"`): those are the distribution's, not this shell's.
{
  description = "Node/Bun dev shell with Playwright's browsers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    playwright.url = "github:pietdevries94/playwright-web-flake/1.61.1";
  };

  outputs =
    { nixpkgs, playwright, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          browsers = playwright.packages.${system}.playwright-driver.browsers;
        in
        {
          default = pkgs.mkShell {
            env = {
              PLAYWRIGHT_BROWSERS_PATH = "${browsers}";
              PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
              # the host-requirements check looks for a distribution's libraries
              PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
            };
          };
        }
      );
    };
}
