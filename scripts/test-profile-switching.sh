#!/bin/bash
set -euo pipefail

# Test profile switching functionality
# Tests both Ansible and chezmoi profile systems

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="${DOTFILES_DIR}/ansible"
CHEZMOI_DIR="${DOTFILES_DIR}/chezmoi"
SKIP_SECRETS="${SKIP_SECRETS:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

test_count=0
pass_count=0
fail_count=0

print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

print_test() {
    echo -e "${YELLOW}[TEST $((++test_count))]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC} $1"
    ((pass_count++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC} $1"
    ((fail_count++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Test 1: Check PROFILE environment variable
test_profile_env() {
    print_test "Checking PROFILE environment variable"
    
    if [[ -z "${PROFILE:-}" ]]; then
        print_fail "PROFILE environment variable not set"
        print_info "Set with: export PROFILE=personal (or work)"
        return 1
    fi
    
    if [[ "$PROFILE" != "personal" && "$PROFILE" != "work" ]]; then
        print_fail "PROFILE must be 'personal' or 'work', got: $PROFILE"
        return 1
    fi
    
    print_pass "PROFILE=$PROFILE"
    return 0
}

# Test 2: Check Ansible inventory
test_ansible_inventory() {
    print_test "Checking Ansible inventory"
    
    if [[ ! -f "${ANSIBLE_DIR}/inventory.yml" ]]; then
        print_fail "Ansible inventory not found"
        return 1
    fi
    
    print_pass "Ansible inventory exists"
    return 0
}

# Test 3: Check Ansible group_vars
test_ansible_group_vars() {
    print_test "Checking Ansible group_vars for profile: $PROFILE"
    
    if [[ ! -f "${ANSIBLE_DIR}/group_vars/${PROFILE}.yml" ]]; then
        print_fail "Profile group_vars not found: ${PROFILE}.yml"
        return 1
    fi
    
    print_pass "Profile group_vars exists: ${PROFILE}.yml"
    return 0
}

# Test 4: Validate Ansible playbook syntax
test_ansible_syntax() {
    print_test "Validating Ansible playbook syntax"

    if ! ansible-playbook "${ANSIBLE_DIR}/playbook.yml" --syntax-check &>/dev/null; then
        print_fail "Ansible playbook syntax check failed"
        return 1
    fi

    print_pass "Ansible playbook syntax valid"
    return 0
}

# Test 4b: Validate secrets skip functionality
test_secrets_skip() {
    print_test "Validating secrets skip functionality (--skip-tags secrets)"

    # Verify the secrets role has proper tags
    if grep -q "tags: \['secrets'\]" "${ANSIBLE_DIR}/roles/secrets/tasks/main.yml"; then
        print_pass "Secrets role has proper 'secrets' tag for skipping"
        if [[ "$SKIP_SECRETS" == "true" ]]; then
            print_info "SKIP_SECRETS=true - secrets will be skipped in ansible runs"
        fi
        return 0
    else
        print_fail "Secrets role missing 'secrets' tag"
        return 1
    fi
}

# Test 5: Check chezmoi configuration
test_chezmoi_config() {
    print_test "Checking chezmoi configuration template"
    
    if [[ ! -f "${CHEZMOI_DIR}/.chezmoi.toml.tmpl" ]]; then
        print_fail "chezmoi config template not found"
        return 1
    fi
    
    print_pass "chezmoi config template exists"
    return 0
}

# Test 6: Test chezmoi template rendering
test_chezmoi_template_render() {
    print_test "Testing chezmoi template rendering for profile: $PROFILE"

    # Create temporary directory for isolated chezmoi test
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    cp -r "${CHEZMOI_DIR}" "$TEMP_DIR/source"

    # Generate config from template with the test profile
    local config_content
    config_content=$(PROFILE=$PROFILE chezmoi execute-template --source="$TEMP_DIR/source" < "$TEMP_DIR/source/.chezmoi.toml.tmpl" 2>/dev/null)

    if [[ -z "$config_content" ]]; then
        print_fail "chezmoi failed to render config template"
        return 1
    fi

    # Write config to temp location
    mkdir -p "$TEMP_DIR/config"
    echo "$config_content" > "$TEMP_DIR/config/chezmoi.toml"

    # Now test template rendering with the generated config
    if chezmoi execute-template --config="$TEMP_DIR/config/chezmoi.toml" --source="$TEMP_DIR/source" '{{ .profile }}' 2>/dev/null | grep -q "$PROFILE"; then
        print_pass "chezmoi renders profile correctly: $PROFILE"
        return 0
    else
        print_fail "chezmoi failed to render profile"
        return 1
    fi
}

# Test 7: Check profile-specific templates
test_profile_templates() {
    print_test "Checking profile-specific template files"
    
    local template_files=()
    
    while IFS= read -r -d '' file; do
        template_files+=("$file")
    done < <(find "${CHEZMOI_DIR}" -name "*.tmpl" -type f -print0)
    
    if [[ ${#template_files[@]} -eq 0 ]]; then
        print_fail "No template files found"
        return 1
    fi
    
    print_pass "Found ${#template_files[@]} template files"
    
    for file in "${template_files[@]}"; do
        print_info "  - $(basename "$file")"
    done
    
    return 0
}

# Test 8: Check template helpers
test_template_helpers() {
    print_test "Checking template helpers"
    
    local helpers_dir="${CHEZMOI_DIR}/.chezmoitemplates"
    
    if [[ ! -d "$helpers_dir" ]]; then
        print_fail "Template helpers directory not found"
        return 1
    fi
    
    local helper_count=$(find "$helpers_dir" -name "*.tmpl" -type f | wc -l)
    
    if [[ $helper_count -eq 0 ]]; then
        print_fail "No template helpers found"
        return 1
    fi
    
    print_pass "Found $helper_count template helpers"
    return 0
}

# Test 9: Dry run chezmoi apply
test_chezmoi_dry_run() {
    print_test "Testing chezmoi dry run for profile: $PROFILE"

    # Create isolated config for testing
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    # Generate config from template with the test profile
    local config_content
    config_content=$(PROFILE=$PROFILE chezmoi execute-template --source="${CHEZMOI_DIR}" < "${CHEZMOI_DIR}/.chezmoi.toml.tmpl" 2>/dev/null)

    mkdir -p "$TEMP_DIR/config"
    echo "$config_content" > "$TEMP_DIR/config/chezmoi.toml"

    # Run dry run with isolated config (suppress verbose output for cleaner test)
    if chezmoi apply --config="$TEMP_DIR/config/chezmoi.toml" --source="${CHEZMOI_DIR}" --dry-run 2>&1 >/dev/null; then
        print_pass "chezmoi dry run successful"
        return 0
    else
        print_fail "chezmoi dry run failed"
        return 1
    fi
}

# Test 10: Check profile differences
test_profile_differences() {
    print_test "Checking for profile-specific differences"
    
    print_info "Comparing personal vs work configurations:"
    
    # Check if files differ between profiles
    local has_differences=false
    
    if [[ -f "${ANSIBLE_DIR}/group_vars/personal.yml" ]] && [[ -f "${ANSIBLE_DIR}/group_vars/work.yml" ]]; then
        if ! diff -q "${ANSIBLE_DIR}/group_vars/personal.yml" "${ANSIBLE_DIR}/group_vars/work.yml" &>/dev/null; then
            has_differences=true
            print_info "  ✓ Ansible group_vars differ"
        fi
    fi
    
    if $has_differences; then
        print_pass "Profile-specific differences detected"
        return 0
    else
        print_fail "No profile-specific differences found (expected some differences)"
        return 1
    fi
}

# Main execution
main() {
    print_header "PROFILE SYSTEM TEST SUITE"
    echo ""
    
    if [[ -z "${PROFILE:-}" ]]; then
        print_info "PROFILE not set, using 'personal' for tests"
        export PROFILE=personal
    fi
    
    echo ""
    print_info "Testing with PROFILE=$PROFILE"
    if [[ "$SKIP_SECRETS" == "true" ]]; then
        print_info "SKIP_SECRETS=true (secrets role will be skipped)"
    fi
    echo ""
    
    # Run all tests
    test_profile_env || true
    echo ""
    test_ansible_inventory || true
    echo ""
    test_ansible_group_vars || true
    echo ""
    test_ansible_syntax || true
    echo ""
    test_secrets_skip || true
    echo ""
    test_chezmoi_config || true
    echo ""
    test_chezmoi_template_render || true
    echo ""
    test_profile_templates || true
    echo ""
    test_template_helpers || true
    echo ""
    test_chezmoi_dry_run || true
    echo ""
    test_profile_differences || true
    echo ""
    
    # Print summary
    print_header "TEST SUMMARY"
    echo ""
    echo "Total tests: $test_count"
    echo -e "${GREEN}Passed: $pass_count${NC}"
    echo -e "${RED}Failed: $fail_count${NC}"
    echo ""
    
    if [[ $fail_count -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Run tests
main "$@"
