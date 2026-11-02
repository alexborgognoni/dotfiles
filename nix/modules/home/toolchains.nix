# Compilers and runtimes that run on Nix: what they need comes from Nix, and
# nothing they would download is an unpatched binary (which needs nix-ld on
# NixOS). The reasons and the rest of the rules: nix/docs/NATIVE-CODE.md.
{ pkgs, ... }:
{
  # Go never downloads another toolchain (go.mod's `toolchain` line, GOTOOLCHAIN
  # =auto): it would be an unpatched binary. Go from Nix is recent; a project
  # that needs another version gets it from its dev shell (templates/go).
  xdg.configFile."go/env".text = ''
    GOTOOLCHAIN=local
  '';

  # rust-analyzer needs the standard library's sources; nixpkgs' rustc has none
  home.sessionVariables.RUST_SRC_PATH = "${pkgs.unstable.rustPlatform.rustLibSrc}";

  # Java from Nix: `java`, `javac` and JAVA_HOME. (Ubuntu's own /usr/bin/java is
  # a headless JRE 11, which jdtls, the Java language server, cannot use.)
  programs.java = {
    enable = true;
    package = pkgs.unstable.jdk;
  };

  # Gradle's toolchains take the JDKs from Nix and never download one (an
  # unpatched binary): a build that asks for Java 17 or 21 finds them here;
  # another version: add it to the list, or use the project's dev shell.
  home.file.".gradle/gradle.properties".text = ''
    org.gradle.java.installations.auto-download=false
    org.gradle.java.installations.paths=${pkgs.unstable.jdk17.home},${pkgs.unstable.jdk21.home}
  '';
}
