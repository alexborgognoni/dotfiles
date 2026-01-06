# GNOME Role

GNOME desktop environment configuration.

## Purpose

Configures the GNOME desktop:
- Theme installation (Catppuccin, icons, cursors)
- GNOME Shell extensions
- Keyboard shortcuts
- dconf settings
- Fonts

## Variables

Settings are defined in `vars/`:

| File | Description |
|------|-------------|
| `common.yml` | Settings for all profiles |
| `personal.yml` | Personal profile settings |
| `work.yml` | Work profile settings |

## Key Variables

| Variable | Description |
|----------|-------------|
| `gnome_extensions` | Extensions to enable |
| `gnome_extensions_disabled` | Extensions to disable |
| `gtk_theme` | GTK theme name |
| `icon_theme` | Icon theme name |
| `cursor_theme` | Cursor theme name |
| `wm_keybindings` | Window manager shortcuts |
| `keyboard_shortcuts` | Media/app shortcuts |

## Tags

- `gnome` - All GNOME tasks
- `gnome-settings` - dconf settings only
- `gnome-extensions` - Extensions only
- `gnome-themes` - Themes only

## Handlers

- `fonts changed` - Refreshes font cache
- `gnome shell reload` - Reloads GNOME Shell

## Dependencies

- `packages` role (for GNOME packages)
