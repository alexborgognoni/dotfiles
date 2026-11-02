# Compilers and runtimes that run on Nix: what they need comes from Nix, and
# nothing they would download is an unpatched binary (which needs nix-ld on
# NixOS). The reasons and the rest of the rules: nix/docs/NATIVE-CODE.md.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Rust: rustup, on every host, so that a project's rust-toolchain.toml is
  # honoured without Nix in the project. nixpkgs' rustup patches the toolchains
  # it downloads (the loader and zlib are Nix's: no host library is needed), so
  # they run on NixOS without nix-ld too. Nix's own toolchain is linked as the
  # default: the baseline is there offline, and a project with a toolchain file
  # gets its channel. (Programs that cargo runs see the toolchain's library
  # directories and zlib in LD_LIBRARY_PATH: that is how the package works.)
  home.packages = [ pkgs.unstable.rustup ];
  home.activation.rustupNix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rustup=${pkgs.unstable.rustup}/bin/rustup
    # never fails the switch
    run $rustup toolchain link nix ${pkgs.rustNixToolchain} || echo "warning: rustup could not link the Nix toolchain" >&2
    # a default only where there is none: one you chose stays
    $rustup show active-toolchain >/dev/null 2>&1 || run $rustup default nix || true
  '';
  # rust-analyzer (Nix's, see languages.nix) needs the standard library sources
  # of the toolchain it analyses; the linked Nix toolchain has none
  home.sessionVariables.RUST_SRC_PATH = "${pkgs.unstable.rustPlatform.rustLibSrc}";

  # Java from Nix: `java`, `javac` and JAVA_HOME. (Ubuntu's own /usr/bin/java is
  # a headless JRE 11, which jdtls, the Java language server, cannot use.)
  programs.java = {
    enable = true;
    package = pkgs.unstable.jdk;
  };

  # Gradle's toolchains: the default JDK is Nix's. A build that asks for another
  # version downloads it on Ubuntu, where it runs natively, and not on NixOS,
  # where an unpatched JDK does not: add the version to `paths` (comma
  # separated, ~800 MB each) or use the project's dev shell. Settings are merged
  # from other modules (corporate/java-truststore.nix), and the file stays Home
  # Manager's; Gradle itself comes with the project's wrapper.
  programs.gradle = {
    enable = true;
    package = null;
    settings = {
      "org.gradle.java.installations.auto-download" = config.my.foreignBinaries;
      "org.gradle.java.installations.paths" = "${pkgs.unstable.jdk.home}";
    };
  };
}
