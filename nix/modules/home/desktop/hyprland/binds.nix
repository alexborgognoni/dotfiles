# Keybindings. The description of each is what the Noctalia keybind
# cheatsheet shows.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  h = import ./lib.nix { inherit config lib pkgs; };
  inherit (h)
    mod
    noctalia
    app
    bind
    bind'
    exec
    execRepeat
    ;
  plugins = config.my.desktop.noctalia.plugins;
  roles = config.my.desktop.mainMonitors != [ ];

  directions = {
    h = "left";
    j = "down";
    k = "up";
    l = "right";
    left = "left";
    down = "down";
    up = "up";
    right = "right";
  };

  workspaceBinds = lib.concatMap (
    i:
    let
      key = toString (lib.mod i 10);
    in
    [
      (
        if roles then
          # Workspaces 1-10 live on the main display: go there first, also from a
          # side display
          exec "Workspace ${toString i}" "${mod} + ${key}" "goto-workspace ${toString i}"
        else
          bind "Workspace ${toString i}" "${mod} + ${key}" "hl.dsp.focus({ workspace = ${toString i} })"
      )
      (bind "Move window to workspace ${toString i}" "${mod} + SHIFT + ${key}"
        "hl.dsp.window.move({ workspace = ${toString i} })"
      )
    ]
  ) (lib.range 1 10);

  directionBinds = lib.concatLists (
    lib.mapAttrsToList (key: dir: [
      (bind "Focus ${dir}" "${mod} + ${key}" "hl.dsp.focus({ direction = \"${dir}\" })")
      (bind "Move window ${dir}" "${mod} + SHIFT + ${key}"
        "hl.dsp.window.move({ direction = \"${dir}\" })"
      )
    ]) directions
  );
in
{
  config = lib.mkIf config.my.features.desktop.enable {
    # Hyprland's default bindings (share/hypr/hyprland.lua) with Noctalia
    # in place of hyprlauncher and the plain volume commands, plus the
    # i3-style keys: Super+Return terminal, Super+Shift+Return browser,
    # Super+Shift+Q close, Super+D launcher, vim keys (Super+O toggle split).
    wayland.windowManager.hyprland.settings.bind = [
      # Hyprland defaults
      (bind "Exit Hyprland" "${mod} + M" "hl.dsp.exit()")
      (exec "File manager" "${mod} + E" (app "nautilus --new-window"))
      (bind "Toggle floating" "${mod} + V" "hl.dsp.window.float({ action = \"toggle\" })")
      (bind "Pseudo-tile window" "${mod} + P" "hl.dsp.window.pseudo()")
      (bind "Scratchpad" "${mod} + S" "hl.dsp.workspace.toggle_special(\"magic\")")
      (bind "Move window to scratchpad" "${mod} + SHIFT + S"
        "hl.dsp.window.move({ workspace = \"special:magic\" })"
      )
      (bind "Next workspace" "${mod} + mouse_down" "hl.dsp.focus({ workspace = \"e+1\" })")
      (bind "Previous workspace" "${mod} + mouse_up" "hl.dsp.focus({ workspace = \"e-1\" })")
      (bind' "Move window" "${mod} + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
      (bind' "Resize window" "${mod} + mouse:273" "hl.dsp.window.resize()" { mouse = true; })

      # i3 style (defaults: Super+Q terminal, Super+C close)
      (exec "Terminal" "${mod} + RETURN" (app "kitty"))
      (exec "Browser" "${mod} + SHIFT + RETURN" (
        app "${pkgs.gtk3}/bin/gtk-launch ${config.my.desktop.browser}"
      ))
      (bind "Close window" "${mod} + SHIFT + Q" "hl.dsp.window.close()")

      # Launcher (default: Super+R with hyprlauncher) and toggle split
      # (default: Super+J, which focuses down here)
      (exec "Launcher" "${mod} + D" "${noctalia} panel-toggle launcher")
      (bind "Toggle split direction" "${mod} + O" "hl.dsp.layout(\"togglesplit\")")

      # Additions
      (exec "Hide/show all bars" "${mod} + B" "toggle-bar all")
      (exec "Hide/show the bar on this monitor" "${mod} + SHIFT + B" "toggle-bar focused")
      (bind "Fullscreen" "${mod} + F" "hl.dsp.window.fullscreen({ action = \"toggle\" })")
      (exec "Clipboard history" "${mod} + SHIFT + V" "${noctalia} panel-toggle clipboard")
      (
        if lib.elem "emoji-picker" plugins then
          exec "Emoji and character picker" "${mod} + period"
            "${noctalia} panel-toggle liamwh/emoji-picker:desktop"
        else
          exec "Emoji picker" "${mod} + period" "${noctalia} panel-toggle launcher /emo"
      )
      (exec "Lock screen" "${mod} + ESCAPE" "${noctalia} session lock")
      (exec "Session menu" "${mod} + SHIFT + ESCAPE" "${noctalia} panel-toggle session")
      (exec "Theme picker" "${mod} + T" "kitty --class theme-picker --title Themes -e theme pick")
      (exec "Accent picker" "${mod} + SHIFT + T"
        "kitty --class theme-picker --title Accent -e theme accent"
      )
      (exec "Screenshot region" "PRINT" "${noctalia} screenshot-region")
      (exec "Screenshot screen" "SHIFT + PRINT" "${noctalia} screenshot-fullscreen")
      (exec "Screenshot window" "${mod} + PRINT" "${noctalia} screenshot-window")
    ]
    ++ lib.optionals (lib.elem "keybind-cheatsheet" plugins) [
      (exec "Keybind cheatsheet" "${mod} + F1"
        "${noctalia} panel-toggle kenn/keybind-cheatsheet:cheatsheet"
      )
    ]
    ++ lib.optionals config.my.desktop.dictation.enable [
      (exec "Dictation: start or stop" "${mod} + SHIFT + I" "voxtype record toggle")
    ]
    ++ lib.optionals (lib.elem "pomodoro" plugins) [
      (exec "Pomodoro start/pause" "${mod} + CTRL + P"
        "${noctalia} plugin thepunkoff/pomodoro:pomodoro all toggle"
      )
    ]
    ++ [

      # Hyprland keeps the layout per keyboard device, so a layout switch of
      # the xkb kind (grp:... options) only reaches the keyboard it was
      # pressed on. One command for all devices, usable on the lock screen.
      (bind' "Next keyboard layout" "${mod} + SPACE"
        "hl.dsp.exec_cmd(\"hyprctl switchxkblayout all next\")"
        { locked = true; }
      )

      # Media keys (as the defaults; Noctalia shows the OSD)
      (execRepeat "Volume up" "XF86AudioRaiseVolume" "${noctalia} volume-up")
      (execRepeat "Volume down" "XF86AudioLowerVolume" "${noctalia} volume-down")
      (execRepeat "Mute" "XF86AudioMute" "${noctalia} volume-mute")
      (execRepeat "Mute microphone" "XF86AudioMicMute" "${noctalia} mic-mute")
      (execRepeat "Brightness up" "XF86MonBrightnessUp" "${noctalia} brightness-up")
      (execRepeat "Brightness down" "XF86MonBrightnessDown" "${noctalia} brightness-down")
      (bind' "Next track" "XF86AudioNext" "hl.dsp.exec_cmd(\"playerctl next\")" { locked = true; })
      (bind' "Previous track" "XF86AudioPrev" "hl.dsp.exec_cmd(\"playerctl previous\")" {
        locked = true;
      })
      (bind' "Play/pause" "XF86AudioPlay" "hl.dsp.exec_cmd(\"playerctl play-pause\")" { locked = true; })
      (bind' "Play/pause" "XF86AudioPause" "hl.dsp.exec_cmd(\"playerctl play-pause\")" { locked = true; })
    ]
    ++ directionBinds
    ++ workspaceBinds;
  };
}
