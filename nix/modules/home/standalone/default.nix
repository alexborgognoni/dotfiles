# Standalone Home Manager on a non-NixOS distribution (the Ubuntu work laptop).
#
#   integration.nix  generic Linux, Nix in every zsh, nh, snapd workaround
#   gpu.nix          GPU drivers for Nix-built GUI apps (my.gpu.nvidia)
#   audio.nix        PipeWire from Nix (my.audio.server)
#   secrets.nix      user-level sops secrets (decrypted with the admin age key)
{
  imports = [
    ./audio.nix
    ./gpu.nix
    ./integration.nix
    ./secrets.nix
  ];
}
