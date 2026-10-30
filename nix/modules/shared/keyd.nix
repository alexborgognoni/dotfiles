# Key remapping data shared by NixOS (services.keyd) and Ubuntu
# (system-manager), on every keyboard, in the console and all sessions.
{
  ids = [ "*" ];

  # Everywhere: Caps Lock = Escape
  settings.main.capslock = "esc";

  # Opt in (corporate laptop): Alt+hjkl = arrow keys
  altArrows.alt = {
    h = "left";
    j = "down";
    k = "up";
    l = "right";
  };
}
