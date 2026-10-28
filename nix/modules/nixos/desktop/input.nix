# Keyboard remapping (modules/shared/keyd.nix, also used on Ubuntu).
{
  services.keyd = {
    enable = true;
    keyboards.default = import ../../shared/keyd.nix;
  };

  # Smartcards (OpenSC)
  services.pcscd.enable = true;
}
