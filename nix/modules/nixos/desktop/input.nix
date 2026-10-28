# Keyboard remapping for every keyboard, in the console and all sessions
# (port of /etc/keyd/default.conf and ~/.Xmodmap from the Ubuntu machine).
{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main.capslock = "esc";
        # Vim-style arrow keys
        alt = {
          h = "left";
          j = "down";
          k = "up";
          l = "right";
        };
      };
    };
  };

  # Smartcards (OpenSC)
  services.pcscd.enable = true;
}
