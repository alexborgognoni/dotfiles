#!/bin/bash
set -euo pipefail

# Dump GNOME settings for backup and configuration management
# Usage: ./scripts/dump-gnome-settings.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${DOTFILES_DIR}/ansible/roles/gnome/files/dconf"

echo "Dumping GNOME settings..."
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Dump full settings (for reference)
echo "1. Dumping full dconf settings..."
dconf dump / > "${OUTPUT_DIR}/full-dump.conf"
echo "   → ${OUTPUT_DIR}/full-dump.conf"

# Dump specific sections
echo "2. Dumping GNOME desktop settings..."
dconf dump /org/gnome/desktop/ > "${OUTPUT_DIR}/desktop-dump.conf"
echo "   → ${OUTPUT_DIR}/desktop-dump.conf"

echo "3. Dumping GNOME shell settings..."
dconf dump /org/gnome/shell/ > "${OUTPUT_DIR}/shell-dump.conf"
echo "   → ${OUTPUT_DIR}/shell-dump.conf"

echo "4. Dumping GNOME extensions settings..."
dconf dump /org/gnome/shell/extensions/ > "${OUTPUT_DIR}/extensions-dump.conf"
echo "   → ${OUTPUT_DIR}/extensions-dump.conf"

echo "5. Dumping keyboard shortcuts..."
dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > "${OUTPUT_DIR}/keybindings-dump.conf"
echo "   → ${OUTPUT_DIR}/keybindings-dump.conf"

echo "6. Dumping window manager settings..."
dconf dump /org/gnome/desktop/wm/ > "${OUTPUT_DIR}/wm-dump.conf"
echo "   → ${OUTPUT_DIR}/wm-dump.conf"

# List installed extensions
echo "7. Listing installed GNOME extensions..."
if command -v gnome-extensions &>/dev/null; then
    gnome-extensions list > "${OUTPUT_DIR}/installed-extensions.txt"
    echo "   → ${OUTPUT_DIR}/installed-extensions.txt"
else
    echo "   ⚠ gnome-extensions command not found, skipping"
fi

echo ""
echo "✅ GNOME settings dumped successfully!"
echo ""
echo "Next steps:"
echo "1. Review the dumped files in ${OUTPUT_DIR}/"
echo "2. Update common.conf, personal.conf, work.conf, and extensions.conf with relevant settings"
echo "3. Commit changes to git"
echo ""
echo "Note: The *-dump.conf files are for reference only."
echo "      Edit the curated config files (common.conf, etc.) to apply settings."
