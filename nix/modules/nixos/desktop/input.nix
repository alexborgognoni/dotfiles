# Keyboard remapping (modules/shared/keyd.nix, also used on Ubuntu): Caps Lock
# = Escape. The Alt+hjkl arrow keys are only for the corporate laptop
# (shared `altArrows`, enabled by modules/system-manager/corporate.nix).
{
  services.keyd = {
    enable = true;
    keyboards.default = {
      inherit (import ../../shared/keyd.nix) ids settings;
    };
  };

  # Smartcards (OpenSC)
  services.pcscd.enable = true;
}
