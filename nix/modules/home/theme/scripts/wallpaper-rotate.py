import os
import sys
import tomllib
from pathlib import Path

import tomli_w

state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
settings_file = state / "noctalia" / "settings.toml"


def load(path):
    try:
        return tomllib.loads(path.read_text())
    except FileNotFoundError:
        return {}


def enabled(data):
    return data.get("wallpaper", {}).get("automation", {}).get("enabled")


settings = load(settings_file)
current = enabled(settings)
if current is None:
    current = bool(enabled(load(config / "noctalia" / "config.toml")))

mode = sys.argv[1] if len(sys.argv) > 1 else "toggle"
if mode not in ("on", "off", "toggle"):
    sys.exit("usage: theme wallpaper rotate [on|off|toggle]")
want = {"on": True, "off": False, "toggle": not current}[mode]

automation = settings.setdefault("wallpaper", {}).setdefault("automation", {})
automation["enabled"] = want
settings_file.parent.mkdir(parents=True, exist_ok=True)
settings_file.write_text(tomli_w.dumps(settings))
print("on" if want else "off")
