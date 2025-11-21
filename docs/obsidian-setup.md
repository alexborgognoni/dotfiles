# Obsidian Setup

## Current Configuration

The Obsidian configuration includes plugins and theme settings that are vault-specific.

### Installed Plugins

- **obsidian-style-settings**: Additional styling options
- **obsidian-linter**: Markdown linting and formatting

### Theme

- **Theme**: Catppuccin
- **Font Family**: JetBrainsMono Nerd Font
- **Font Size**: 17

## Setting Up a New Vault

When setting up a new Obsidian vault, copy the reference `.obsidian` directory from `examples/.obsidian/` to your vault directory.

### Files to Configure

1. **community-plugins.json**: List of enabled community plugins
2. **appearance.json**: Theme and font configuration

### Installing Plugins

After copying the configuration:
1. Open Obsidian
2. Go to Settings → Community plugins
3. Install the plugins listed in `community-plugins.json`
4. Enable them in the Community plugins section

### Installing Theme

1. Go to Settings → Appearance → Themes
2. Search for and install "Catppuccin"
3. Apply the theme

## Locations

- Global config: `~/.config/obsidian/`
- Vault config: `<vault-directory>/.obsidian/`
- Example config: `examples/.obsidian/` (in this repository)
