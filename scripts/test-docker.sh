#!/bin/bash
set -euo pipefail

###############################################################################
# Docker Test Suite
# Tests non-GUI components of the dotfiles setup in a Docker container
###############################################################################

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
section() { echo -e "\n${GREEN}==>${NC} $1\n"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${PROFILE:-personal}"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Docker Test Suite - Non-GUI Components            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
info "Profile: $PROFILE"
info "Dotfiles: $SCRIPT_DIR"
echo ""

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if we have a Dockerfile
if [[ ! -f "$SCRIPT_DIR/tests/Dockerfile" ]]; then
    error "Dockerfile not found. Creating test infrastructure..."
    mkdir -p "$SCRIPT_DIR/tests"

    cat > "$SCRIPT_DIR/tests/Dockerfile" << 'EOF'
FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PROFILE=personal

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create test user with sudo
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to test user
USER testuser
WORKDIR /home/testuser

# Copy dotfiles
COPY --chown=testuser:testuser . /home/testuser/dotfiles

# Set working directory
WORKDIR /home/testuser/dotfiles

CMD ["/bin/bash"]
EOF
    success "Created Dockerfile at tests/Dockerfile"
fi

section "Building Docker Image"
info "Building test image (this may take a while)..."
if docker build -t dotfiles-test -f "$SCRIPT_DIR/tests/Dockerfile" "$SCRIPT_DIR"; then
    success "Docker image built successfully"
else
    error "Failed to build Docker image"
    exit 1
fi

section "Running Tests in Container"
info "Starting container and running tests..."

# Run container with tests
docker run --rm \
    -e PROFILE="$PROFILE" \
    dotfiles-test \
    bash -c "
        set -euo pipefail

        echo '==> Installing Ansible and chezmoi'
        sudo apt-get update -qq
        sudo apt-get install -y -qq ansible unzip > /dev/null 2>&1

        # Install chezmoi
        cd /tmp
        curl -sfL https://git.io/chezmoi | sh > /dev/null 2>&1
        sudo mv ./bin/chezmoi /usr/local/bin/

        cd /home/testuser/dotfiles

        echo '==> Testing Ansible Playbook Syntax'
        if ansible-playbook ansible/playbook.yml --syntax-check; then
            echo '✓ Ansible syntax valid'
        else
            echo '✗ Ansible syntax check failed'
            exit 1
        fi

        echo '==> Testing Profile System'
        if chezmoi execute-template --source=chezmoi '{{ .profile }}' | grep -q '$PROFILE'; then
            echo \"✓ Profile system working: \$PROFILE\"
        else
            echo '✗ Profile system failed'
            exit 1
        fi

        echo '==> Testing chezmoi Dry Run'
        if chezmoi apply --source=chezmoi --dry-run > /dev/null 2>&1; then
            echo '✓ chezmoi dry run successful'
        else
            echo '✗ chezmoi dry run failed'
            exit 1
        fi

        echo '==> Testing Package Installation (apt only, no GNOME)'
        # Test just the package role without GNOME
        if ansible-playbook ansible/playbook.yml --tags=packages --check --diff -v; then
            echo '✓ Package installation tasks valid'
        else
            echo '✗ Package installation check failed'
            exit 1
        fi

        echo ''
        echo '╔═══════════════════════════════════════════════════════════╗'
        echo '║                   Docker Tests PASSED                     ║'
        echo '╚═══════════════════════════════════════════════════════════╝'
        echo ''
        echo 'Note: GNOME and GUI components cannot be tested in Docker.'
        echo 'Please test the full system in a VM or fresh installation.'
    "

exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    echo ""
    success "All Docker tests passed!"
    echo ""
    info "Next steps:"
    echo "  1. Review test results above"
    echo "  2. Test full system in VM with: scripts/test-vm.sh"
    echo "  3. Or test on fresh Ubuntu installation"
    echo ""
else
    echo ""
    error "Some Docker tests failed!"
    echo ""
    info "Check the output above for details"
    exit 1
fi
