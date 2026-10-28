{
  # greetd + ReGreet (GTK greeter running in cage); themed by Stylix.
  programs.regreet.enable = true;

  services.displayManager.defaultSession = "hyprland-uwsm";

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
}
