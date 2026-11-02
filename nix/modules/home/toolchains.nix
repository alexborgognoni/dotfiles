# Compilers and runtimes that run on Nix: what they need comes from Nix, and
# nothing they would download is an unpatched binary (which needs nix-ld on
# NixOS). The reasons and the rest of the rules: nix/docs/NATIVE-CODE.md.
{
  config,
  pkgs,
  ...
}:
{
  # rust-analyzer needs the standard library's sources; nixpkgs' rustc has none
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
