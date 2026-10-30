# Helpers shared by the Hyprland modules:
#   h = import ./lib.nix { inherit config lib pkgs; };
{
  config,
  lib,
  pkgs,
}:
let
  inline = lib.generators.mkLuaInline;
in
rec {
  mod = "SUPER";
  noctalia = "noctalia msg";

  # On NixOS, UWSM starts each app in its own systemd unit; standalone
  # sessions have no UWSM.
  app = cmd: if config.my.standalone then cmd else "uwsm app -- ${cmd}";

  # bind "Close window" "SUPER + Q" "hl.dsp.window.close()" { locked = true; }
  # The description is what the Noctalia keybind cheatsheet shows.
  bind' = description: keys: dispatcher: opts: {
    _args = [
      keys
      (inline dispatcher)
      (opts // { inherit description; })
    ];
  };
  bind =
    description: keys: dispatcher:
    bind' description keys dispatcher { };
  exec =
    description: keys: cmd:
    bind description keys "hl.dsp.exec_cmd(${builtins.toJSON cmd})";
  execRepeat =
    description: keys: cmd:
    bind' description keys "hl.dsp.exec_cmd(${builtins.toJSON cmd})" {
      locked = true;
      repeating = true;
    };

  # A helper script from ./scripts/<name>.sh. `substitute` replaces
  # placeholders (@name@) with values from the configuration.
  script =
    {
      name,
      runtimeInputs ? [ ],
      substitute ? { },
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = lib.replaceStrings (lib.attrNames substitute) (lib.attrValues substitute) (
        builtins.readFile (./scripts + "/${name}.sh")
      );
    };
}
