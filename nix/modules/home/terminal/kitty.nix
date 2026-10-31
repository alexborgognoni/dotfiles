# kitty. Font and opacity come from Stylix; colors
# come from the live theme pack, so open windows recolor on theme preview.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.features.gui.enable {
    stylix.targets.kitty.colors.enable = false;

    programs.kitty = {
      enable = true;
      package = pkgs.unstable.kitty;

      # Without its `sudo` wrapper (it runs `sudo TERMINFO=...`, which sudoers
      # refuses for the allow-listed commands) and without its cursor change
      # (a beam at the prompt): the cursor stays a block
      shellIntegration.mode = "enabled no-sudo no-cursor";

      settings = {
        url_style = "curly";
        detect_urls = "yes";
        open_url_with = "default";
        underline_hyperlinks = "always";

        input_delay = 3;
        confirm_os_window_close = 0;
        hide_window_decorations = "no";
        wheel_scroll_multiplier = 1;

        # The pointer hides after 3 s without movement and returns with the next
        # move (kitty's default on Linux, pinned so it stays)
        mouse_hide_wait = "3.0";

        cursor_shape = "block";
        cursor_trail = 3;
        cursor_trail_decay = "0.2 0.3";

        enable_audio_bell = "yes";
        bell_path = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/bell.oga";

        # Lets the `theme` command recolor running windows.
        allow_remote_control = "socket-only";
        listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty-{kitty_pid}";
        dynamic_background_opacity = "yes";

        # Every kitty window attaches to the shared tmux session.
        startup_session = "startup.conf";
      };

      keybindings."ctrl+shift+v" = "paste_from_clipboard";

      extraConfig = ''
        include ${config.my.themeState}/current/kitty.conf

        symbol_map U+e000-U+e00a,U+e0a0-U+e0a2,U+e0a3,U+e0b0-U+e0b3,U+e0b4-U+e0c8,U+e0ca,U+e0cc-U+e0d7,U+e200-U+e2a9,U+e300-U+e3e3,U+e5fa-U+e6b7,U+e700-U+e8ef,U+ea60-U+ec1e,U+ed00-U+efce,U+f000-U+f2ff,U+f300-U+f381,U+f400-U+f533,U+f0001-U+f1af0 Symbols Nerd Font Mono

        mouse_map shift+left click ungrabbed mouse_handle_click selection link prompt
        mouse_map shift+left click grabbed,ungrabbed mouse_handle_click selection link prompt
      '';
    };

    xdg.configFile."kitty/startup.conf".text = ''
      launch sh -c "tmux new-session -A -s main"
    '';
  };
}
