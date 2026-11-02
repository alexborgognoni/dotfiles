# Rust dev shell: the libraries a -sys crate links against (openssl-sys, ...) and,
# if the project wants everything from Nix, its toolchain from rust-toolchain.toml
# (channel, nightly, components, targets) through rust-overlay.
#
# Without this, rustup (on every host, see modules/home/toolchains.nix) already
# honours a project's rust-toolchain.toml: nixpkgs' rustup patches the toolchains
# it downloads, so they run on NixOS too. What rustup cannot give is a *library*:
# Nix's compiler sees only what Nix provides, never the distribution's
# /usr/include and /usr/lib, so a library a -sys crate links against is named in
# buildInputs (docs/NATIVE-CODE.md). Without a rust-toolchain.toml, replace
# `fromRustupToolchainFile ./rust-toolchain.toml` with
# `rust-bin.stable.latest.default` (or `rust-bin.nightly.latest.default`).
{
  description = "Rust dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, rust-overlay, ... }:
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
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };
          toolchain = (pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml).override {
            extensions = [
              "rust-src"
              "rust-analyzer"
            ];
          };
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [
              toolchain
              pkgs.pkg-config
            ];
            buildInputs = with pkgs; [
              openssl
              zlib
            ];
            RUST_SRC_PATH = "${toolchain}/lib/rustlib/src/rust/library";
          };
        }
      );
    };
}
