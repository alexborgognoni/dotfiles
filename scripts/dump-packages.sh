#!/bin/bash
set -euo pipefail

###############################################################################
# Package Dump Script
# Exports currently installed packages to YAML files
# Uses existing Ansible vars as the source of truth for filtering
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
VARS_DIR="$DOTFILES_DIR/ansible/roles/packages/vars"

echo "Dumping packages from current system..."
echo "Using existing Ansible vars as filter source"
echo ""

###############################################################################
# Extract existing package names from Ansible vars (source of truth)
###############################################################################

extract_packages_from_yaml() {
    local file="$1"
    local prefix="$2"
    if [[ -f "$file" ]]; then
        grep -E "^\s+-\s+name:\s+" "$file" 2>/dev/null | sed 's/.*name:\s*//' | tr -d '"' | tr -d "'" || true
    fi
}

# Build filter list from existing Ansible vars
echo "Reading existing package definitions from Ansible vars..."
{
    extract_packages_from_yaml "$VARS_DIR/common.yml" "common"
    extract_packages_from_yaml "$VARS_DIR/personal.yml" "personal"
    extract_packages_from_yaml "$VARS_DIR/work.yml" "work"
} | sort -u > /tmp/known-packages.txt

known_count=$(wc -l < /tmp/known-packages.txt)
echo "Found $known_count known packages in Ansible vars"
echo ""

###############################################################################
# APT Packages
###############################################################################

echo "📦 Dumping apt packages..."
apt-mark showmanual | sort > /tmp/apt-manual-all.txt

# Filter to only known packages (from Ansible vars)
if [[ -s /tmp/known-packages.txt ]]; then
    grep -Fxf /tmp/known-packages.txt /tmp/apt-manual-all.txt > /tmp/apt-final.txt 2>/dev/null || true
else
    # If no known packages, show all manual packages
    cp /tmp/apt-manual-all.txt /tmp/apt-final.txt
fi

apt_count=$(wc -l < /tmp/apt-final.txt)
apt_total=$(wc -l < /tmp/apt-manual-all.txt)
echo "Found $apt_count apt packages (of $apt_total total manually installed)"

# Show new packages not in Ansible vars
comm -23 /tmp/apt-manual-all.txt /tmp/known-packages.txt > /tmp/apt-new.txt 2>/dev/null || true
new_count=$(wc -l < /tmp/apt-new.txt)
if [[ $new_count -gt 0 ]]; then
    echo "  ⚠ $new_count packages not in Ansible vars (run with --show-new to see)"
fi

###############################################################################
# Snap Packages
###############################################################################

echo "📦 Dumping snap packages..."
snap list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v "^core" | grep -v "^gnome-" | grep -v "^gtk-" | grep -v "snapd" | sort > /tmp/snap-packages.txt || echo "" > /tmp/snap-packages.txt
echo "Found $(wc -l < /tmp/snap-packages.txt) snap packages"

###############################################################################
# Cargo Packages
###############################################################################

echo "📦 Dumping cargo packages..."
if command -v cargo &>/dev/null; then
    cargo install --list 2>/dev/null | grep "^[a-z]" | awk '{print $1}' | sort > /tmp/cargo-packages.txt
else
    echo "" > /tmp/cargo-packages.txt
fi
echo "Found $(wc -l < /tmp/cargo-packages.txt) cargo packages"

###############################################################################
# Pip Packages
###############################################################################

echo "📦 Dumping pip packages..."
pip list --format=freeze 2>/dev/null | grep -v "^-e" | cut -d'=' -f1 | sort > /tmp/pip-all-packages.txt || echo "" > /tmp/pip-all-packages.txt

# Filter to known packages from Ansible vars
if [[ -s /tmp/known-packages.txt ]]; then
    grep -Fxf /tmp/known-packages.txt /tmp/pip-all-packages.txt > /tmp/pip-packages.txt 2>/dev/null || echo "" > /tmp/pip-packages.txt
else
    cp /tmp/pip-all-packages.txt /tmp/pip-packages.txt
fi
echo "Found $(wc -l < /tmp/pip-packages.txt) pip packages"

###############################################################################
# NPM Global Packages
###############################################################################

echo "📦 Dumping npm global packages..."
if command -v npm &>/dev/null; then
    npm list -g --depth=0 2>/dev/null | grep -v "npm@" | awk '{print $2}' | grep "@" | cut -d'@' -f1 | sort > /tmp/npm-packages.txt || echo "" > /tmp/npm-packages.txt
else
    echo "" > /tmp/npm-packages.txt
fi
echo "Found $(wc -l < /tmp/npm-packages.txt) npm packages"

###############################################################################
# Homebrew Packages
###############################################################################

echo "📦 Dumping homebrew packages..."
if command -v brew &>/dev/null; then
    brew list --formula 2>/dev/null | sort > /tmp/brew-packages.txt || echo "" > /tmp/brew-packages.txt
else
    echo "" > /tmp/brew-packages.txt
fi
echo "Found $(wc -l < /tmp/brew-packages.txt) brew packages"

###############################################################################
# Show new packages if requested
###############################################################################

if [[ "${1:-}" == "--show-new" ]]; then
    echo ""
    echo "New APT packages not in Ansible vars:"
    echo "======================================"
    cat /tmp/apt-new.txt
    echo ""
    echo "To add these, edit: $VARS_DIR/common.yml"
fi

###############################################################################
# Generate Report
###############################################################################

echo ""
echo "════════════════════════════════════════════════════════════"
echo "                    PACKAGE DUMP COMPLETE"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Package counts:"
echo "  APT:   $apt_count packages"
echo "  Snap:  $(wc -l < /tmp/snap-packages.txt) packages"
echo "  Cargo: $(wc -l < /tmp/cargo-packages.txt) packages"
echo "  Pip:   $(wc -l < /tmp/pip-packages.txt) packages"
echo "  NPM:   $(wc -l < /tmp/npm-packages.txt) packages"
echo "  Brew:  $(wc -l < /tmp/brew-packages.txt) packages"
echo ""
echo "Package lists saved to /tmp/*-packages.txt"
echo ""
echo "To see new packages not in Ansible vars:"
echo "  $0 --show-new"
echo ""
echo "To update Ansible vars, manually edit:"
echo "  $VARS_DIR/common.yml"
echo "  $VARS_DIR/personal.yml"
echo "  $VARS_DIR/work.yml"
echo ""
