# A popup (Noctalia OSD) when the keyboard backlight level changes, as GNOME
# showed. On a ThinkPad, Fn+Space changes the level in the firmware: nothing
# reaches the session, so the popup has to come from the backlight itself.
# UPower reports every change on the system bus (BrightnessChanged), whoever
# made it: the key, Noctalia or a script.
#
# Not tied to a machine: the service only starts where a keyboard backlight
# (a kernel LED named *kbd_backlight) exists, and works with any level count
# (ThinkPad: off, low, high). A backlight outside the kernel's LED class, such
# as an external keyboard with its own protocol, is not covered.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  noctalia = config.programs.noctalia.package;

  osd = pkgs.writeShellApplication {
    name = "kbd-backlight-osd";
    runtimeInputs = [
      pkgs.glib
      pkgs.coreutils
      noctalia
    ];
    text = ''
      kbd=(--system --dest org.freedesktop.UPower --object-path /org/freedesktop/UPower/KbdBacklight)

      max="$(gdbus call "''${kbd[@]}" --method org.freedesktop.UPower.KbdBacklight.GetMaxBrightness | tr -dc '0-9')"
      [ "''${max:-0}" -gt 0 ] || exit 0

      show() {
        local level="$1" label icon extra="" percent
        percent=$((level * 100 / max))
        if [ "$level" -eq 0 ]; then
          label=Off icon=keyboard-off extra=',"inactive":true'
        else
          icon=keyboard
          if [ "$max" -eq 1 ]; then
            label=On
          elif [ "$max" -eq 2 ]; then
            if [ "$level" -eq 1 ]; then label=Low; else label=High; fi
          else
            label="$((level * 100 / max))%"
          fi
        fi
        noctalia msg osd-show "{\"icon\":\"$icon\",\"value\":\"Keyboard backlight: $label\",\"progress\":$((percent / 100)).$(printf '%02d' $((percent % 100)))$extra}" >/dev/null || true
      }

      gdbus monitor "''${kbd[@]}" | while read -r line; do
        case "$line" in
          *.BrightnessChanged\ \(*)
            level="''${line##*(}"
            show "''${level%%,*}"
            ;;
        esac
      done
    '';
  };
in
{
  config = lib.mkIf config.my.features.desktop.enable {
    systemd.user.services.kbd-backlight-osd = lib.mkMerge [
      {
        Unit = {
          Description = "Keyboard backlight popup";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          ConditionPathExistsGlob = "/sys/class/leds/*kbd_backlight";
        };
        Service = {
          ExecStart = "${osd}/bin/kbd-backlight-osd";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      }
      # Standalone, GNOME starts graphical-session.target too (as for Noctalia)
      (lib.mkIf config.my.standalone {
        Unit.PartOf = lib.mkForce [ "hyprland-session.target" ];
        Unit.After = lib.mkForce [ "hyprland-session.target" ];
        Install.WantedBy = lib.mkForce [ "hyprland-session.target" ];
      })
    ];
  };
}
