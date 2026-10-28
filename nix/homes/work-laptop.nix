# Ubuntu 22.04 work laptop (Intel + NVIDIA RTX A2000, PRIME on-demand),
# standalone Home Manager. Ubuntu keeps the OS, GNOME, drivers, corporate
# software and system services (see ../../ansible/ubuntu.yml); Nix provides
# everything user-level, including the Hyprland session.
#
#   nh home switch            (or: home-manager switch --flake ~/dotfiles/nix#alex@work-laptop)
{
  home = {
    username = "Alex";
    homeDirectory = "/home/Alex";
    stateVersion = "26.05";
  };

  my = {
    standalone = true;
    profile = "work";

    features = {
      gui.enable = true;
      # Hyprland + Noctalia as an extra GDM session ("Hyprland (Nix)"); GNOME
      # stays available and keeps its look (my.desktop.themeToolkits = false).
      desktop.enable = true;
    };

    # Chrome and Edge stay on apt (Intune/Entra sign-in integration).
    packages.groups = [
      "cli"
      "gui"
    ];

    keyboard.layout = "gb";

    gpu.nvidia = {
      version = "595.84";
      sha256 = "sha256-mcQE5SExvye8ptoCaNzOPr7cenOrF0BxqZXPGmxeugY=";
    };
  };
}
