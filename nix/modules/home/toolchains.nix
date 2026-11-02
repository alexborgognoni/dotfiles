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

  # Gradle's toolchains take the JDK from Nix and never download one (an
  # unpatched binary): a build that asks for the default Java finds it here.
  # Another version costs ~800 MB, so it is not installed on every host: add
  # it to `paths` (comma separated) or use the project's dev shell. Settings
  # are merged from other modules (corporate/java-truststore.nix), and the
  # file stays Home Manager's; Gradle itself comes with the project's wrapper.
  programs.gradle = {
    enable = true;
    package = null;
    settings = {
      "org.gradle.java.installations.auto-download" = false;
      "org.gradle.java.installations.paths" = "${pkgs.unstable.jdk.home}";
    };
  };
}
