# Main display and bars. Main display = first connected of
# my.desktop.mainMonitors (by description), else the internal panel.
# Workspaces 1-10 live there (the others keep the leftover ones) and Noctalia
# shows its full bar there and the workspaces-only bar elsewhere.
#
#   monitor-roles    moves what is on the wrong display and picks the bars;
#                    idempotent, one copy at a time
#   goto-workspace   Super+N: the main display first, then workspace N
#   toggle-bar       Super+B (all bars) / Super+Shift+B (this display's bar)
#
# Only start, plug and unplug (and new workspaces and windows) trigger
# monitor-roles: its own effects raise layout events, and workspace_rule at
# runtime re-applies the monitor setup (a modeset loop that flashes the
# screens), so neither is listened to.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  h = import ./lib.nix { inherit config lib pkgs; };
  roles = config.my.desktop.mainMonitors != [ ];

  monitorRoles = h.script {
    name = "monitor-roles";
    runtimeInputs = [
      pkgs.jq
      pkgs.util-linux
    ];
    substitute."@mainMonitors@" = lib.escapeShellArgs config.my.desktop.mainMonitors;
  };

  # Role-aware (monitor-roles keeps which bar each display shows): Noctalia's
  # own toggle would also flip the bars that are hidden on purpose.
  toggleBar = h.script {
    name = "toggle-bar";
    runtimeInputs = [ pkgs.jq ];
  };

  # Super+N: focus the main display (the one monitor-roles records), then
  # workspace N, so the key works the same from a side display
  gotoWorkspace = h.script { name = "goto-workspace"; };
in
{
  config = lib.mkIf config.my.features.desktop.enable {
    home.packages = [
      toggleBar
    ]
    ++ lib.optionals roles [
      monitorRoles
      gotoWorkspace
    ];

    # A switch makes Noctalia reload its config, which brings back both bars
    home.activation.monitorRoles = lib.mkIf roles (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ( sleep 4; ${monitorRoles}/bin/monitor-roles --force ) >/dev/null 2>&1 &
      ''
    );

    wayland.windowManager.hyprland.extraConfig = lib.mkIf roles (
      lib.mkOrder 700 ''
        hl.on("hyprland.start", function() hl.exec_cmd("monitor-roles") end)
        hl.on("monitor.added", function() hl.exec_cmd("monitor-roles") end)
        hl.on("monitor.removed", function() hl.exec_cmd("monitor-roles") end)
        -- the autostart apps open their windows after login; the script moves
        -- their workspaces to the main display and does nothing when all is in
        -- place (it never moves empty workspaces: that would loop)
        hl.on("workspace.created", function() hl.exec_cmd("monitor-roles") end)
        hl.on("window.open", function() hl.exec_cmd("monitor-roles") end)
      ''
    );
  };
}
