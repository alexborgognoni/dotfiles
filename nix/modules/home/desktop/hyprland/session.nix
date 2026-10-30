# The session itself: the wrapper the display manager starts (standalone) and
# the apps started once per session (my.desktop.autostart).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  h = import ./lib.nix { inherit config lib pkgs; };
  standalone = config.my.standalone;

  # The session's apps start only once the user manager knows the Wayland
  # display and the settings portal answers with a colour scheme. An app
  # started earlier (Chrome at login) never learns the scheme the portal
  # reports a moment later, and stays light. Gives up after 40 s.
  waitSession = h.script {
    name = "wait-session";
    runtimeInputs = [ pkgs.glib ];
  };
in
{
  config = lib.mkIf config.my.features.desktop.enable {
    home.packages = [
      waitSession
    ]
    # Standalone (Ubuntu): the session the display manager starts. The system
    # layer installs a wayland-sessions entry pointing here.
    ++ lib.optionals standalone [
      (pkgs.writeShellScriptBin "hyprland-session" ''
        # Home Manager session variables (XDG_DATA_DIRS for Nix apps, ...)
        if [ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
          . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
        fi
        export XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_DESKTOP=Hyprland
        exec ${pkgs.unstable.hyprland}/bin/start-hyprland
      '')
    ];

    # Started once per session, the windows of each launch placed on their
    # workspace (window rules: rules.nix)
    wayland.windowManager.hyprland.extraConfig = lib.mkIf (config.my.desktop.autostart != [ ]) (
      lib.mkOrder 600 ''
        hl.on("hyprland.start", function()
        ${
          lib.concatMapStrings (
            a:
            let
              rules = lib.optionalString (
                a.workspace != null && a.class == null
              ) ", { workspace = \"${toString a.workspace} silent\" }";
            in
            "  hl.exec_cmd(${builtins.toJSON "wait-session; exec ${h.app a.command}"}${rules})\n"
          ) config.my.desktop.autostart
        }end)
      ''
    );
  };
}
