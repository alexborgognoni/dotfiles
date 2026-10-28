# Keyboard remapping shared by NixOS (services.keyd) and Ubuntu
# (system-manager): Caps Lock = Escape, Alt+hjkl = arrow keys, on every
# keyboard, in the console and all sessions.
{
  ids = [ "*" ];
  settings = {
    main.capslock = "esc";
    alt = {
      h = "left";
      j = "down";
      k = "up";
      l = "right";
    };
  };
}
