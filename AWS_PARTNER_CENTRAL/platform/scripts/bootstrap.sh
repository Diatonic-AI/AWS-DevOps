#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for Partner Central Wrapper Platform
# This script sets up the development environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=()

    # Check for required tools
    command -v python3 >/dev/null 2>&1 || missing+=("python3")
    command -v pip3 >/dev/null 2>&1 || missing+=("pip3")
    command -v aws >/dev/null 2>&1 || missing+=("aws-cli")
    command -v terraform >/dev/null 2>&1 || missing+=("terraform")
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v jq >/dev/null 2>&1 || missing+=("jq")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        log_info "Please install the missing tools and re-run this script."
        exit 1
    fi

    log_info "All prerequisites satisfied."
}

# Copy example config files
setup_config() {
    log_info "Setting up configuration files..."

    local config_dir="$PROJECT_ROOT/platform/config"

    # Copy example files if real files don't exist
    if [[ -f "$config_dir/tenants.example.yaml" && ! -f "$config_dir/tenants.yaml" ]]; then
        cp "$config_dir/tenants.example.yaml" "$config_dir/tenants.yaml"
        log_info "Created tenants.yaml from example"
    fi

    # Create .env file from example if it doesn't exist
    if [[ -f "$PROJECT_ROOT/.env.example" && ! -f "$PROJECT_ROOT/.env" ]]; then
        cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
        log_info "Created .env from example"
    fi
}

# Install Python dependencies
install_python_deps() {
    log_info "Installing Python dependencies..."

    if [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
        pip3 install -r "$PROJECT_ROOT/requirements.txt" --quiet
    else
        # Install minimum required packages
        pip3 install pyyaml jsonschema --quiet
    fi

    log_info "Python dependencies installed."
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."

    if [[ -f "$SCRIPT_DIR/validate-config.py" ]]; then
        python3 "$SCRIPT_DIR/validate-config.py"
    else
        log_warn "validate-config.py not found, skipping validation"
    fi
}

# Initialize Terraform backend (local development)
init_terraform() {
    log_info "Initializing Terraform..."

    local tf_dir="$PROJECT_ROOT/infra/terraform/envs/dev"

    if [[ -d "$tf_dir" ]]; then
        cd "$tf_dir"
        # Initialize with local backend for development
        terraform init -backend=false 2>/dev/null || log_warn "Terraform init skipped (may need AWS credentials)"
        cd "$PROJECT_ROOT"
    else
        log_warn "Terraform dev environment not found at $tf_dir"
    fi
}

# Create required directories
create_directories() {
    log_info "Creating required directories..."

    mkdir -p "$PROJECT_ROOT/data"
    mkdir -p "$PROJECT_ROOT/logs"
    mkdir -p "$PROJECT_ROOT/artifacts"

    log_info "Directories created."
}

# Check AWS credentials
check_aws_credentials() {
    log_info "Checking AWS credentials..."

    if aws sts get-caller-identity >/dev/null 2>&1; then
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        log_info "AWS credentials valid. Account: $account_id"
    else
        log_warn "AWS credentials not configured or invalid."
        log_warn "Some features will not work without valid AWS credentials."
    fi
}

# Print next steps
print_next_steps() {
    echo ""
    log_info "Bootstrap complete! Next steps:"
    echo ""
    echo "  1. Review and customize configuration files in platform/config/"
    echo "  2. Set up AWS credentials (if not done):"
    echo "     aws configure"
    echo ""
    echo "  3. Deploy infrastructure (dev):"
    echo "     cd infra/terraform/envs/dev"
    echo "     terraform init"
    echo "     terraform plan"
    echo "     terraform apply"
    echo ""
    echo "  4. Deploy services (dev):"
    echo "     cd infra/ansible"
    echo "     ansible-playbook -i inventories/dev.ini playbooks/site.yml"
    echo ""
    echo "  For more information, see README.md and docs/spec/"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║     Partner Central Wrapper Platform - Bootstrap Script       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    cd "$PROJECT_ROOT"

    check_prerequisites
    create_directories
    setup_config
    install_python_deps
    validate_config
    check_aws_credentials
    init_terraform
    print_next_steps
}

main "$@"
