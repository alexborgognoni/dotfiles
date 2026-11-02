# The retreat switch for the runtimes (docs/NATIVE-CODE.md, "If this becomes a
# burden").
#
# true   bun, python and lua are patched so that prebuilt native code loads
#        (pkgs/*-native-libs), and a host that cannot run a foreign binary
#        (NixOS) downloads none.
# false  plain nixpkgs runtimes, nothing patched: every host may run foreign
#        binaries (mise, uv's standalone Pythons, Gradle's JDKs); NixOS runs
#        them with nix-ld (modules/nixos/core/nix-ld.nix). The Ubuntu laptop
#        already works that way for what the Nix set lacks.
#
# Flip it when a nixpkgs update breaks the patched runtimes more than once.
{
  patched = true;
}
