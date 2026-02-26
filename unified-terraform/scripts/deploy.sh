#!/usr/bin/env bash

# Unified Terraform Deployment Script
# Manages all environments and applications through a single interface
# Version: 2.0.0

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1" >&2
}

# Usage information
usage() {
    cat << EOF
Unified Terraform Deployment Script

USAGE:
    $0 <workspace> <command> [options]

WORKSPACES:
    dev         - Development environment (default)
    staging     - Staging environment
    prod        - Production environment
    ai-nexus    - AI Nexus Workbench (dev environment)
    minio       - MinIO infrastructure (dev environment)
    all         - All workspaces (for certain commands)

COMMANDS:
    init            - Initialize Terraform and create workspace
    plan            - Generate execution plan
    apply           - Apply changes (with approval for prod)
    destroy         - Destroy infrastructure (with confirmation)
    validate        - Validate configuration
    format          - Format Terraform files
    show            - Show current state
    output          - Show outputs
    workspace       - Workspace management
    state           - State management operations
    import          - Import existing resources
    migrate         - Migrate from old configurations

OPTIONS:
    -h, --help      - Show this help message
    -v, --verbose   - Verbose output
    -y, --yes       - Auto-approve (use with caution)
    -d, --dry-run   - Show what would be done
    --var-file=FILE - Additional variable file
    --target=RESOURCE - Target specific resource

EXAMPLES:
    $0 dev plan                     # Plan development environment
    $0 staging apply                # Apply staging environment
    $0 prod apply --var-file=prod-overrides.tfvars
    $0 ai-nexus plan                # Plan AI Nexus workbench
    $0 all validate                 # Validate all workspaces

SETUP (First Time):
    1. $0 backend setup             # Create S3 backend
    2. $0 dev init                  # Initialize development
    3. $0 dev plan                  # Plan first deployment

EOF
}

# Workspace validation
validate_workspace() {
    local workspace=$1
    local valid_workspaces=("dev" "staging" "prod" "ai-nexus" "minio" "all" "backend")
    
    if [[ ! " ${valid_workspaces[*]} " =~ " $workspace " ]]; then
        log_error "Invalid workspace: $workspace"
        log_info "Valid workspaces: ${valid_workspaces[*]}"
        exit 1
    fi
}

# Environment protection
check_environment_protection() {
    local workspace=$1
    local command=$2
    
    if [[ "$workspace" == "prod" ]]; then
        case "$command" in
            apply|destroy)
                if [[ "${AUTO_APPROVE:-false}" != "true" ]]; then
                    log_warning "This is a PRODUCTION environment!"
                    log_warning "Command: $command"
                    echo -n "Are you sure you want to continue? (yes/no): "
                    read -r confirmation
                    if [[ "$confirmation" != "yes" ]]; then
                        log_info "Operation cancelled."
                        exit 0
                    fi
                fi
                ;;
        esac
    fi
}

# Backend setup
setup_backend() {
    log_step "Setting up Terraform backend infrastructure"
    
    cd "$SCRIPT_DIR"
    
    if [[ -f "setup-backend.tf" ]]; then
        log_info "Initializing backend setup"
        terraform init
        
        log_info "Planning backend resources"
        terraform plan -out=backend-setup.tfplan
        
        log_info "Applying backend resources"
        terraform apply backend-setup.tfplan
        
        log_success "Backend setup completed!"
        log_info "Backend configuration saved to: $PROJECT_ROOT/backend-config.txt"
        
        # Show the backend configuration
        if [[ -f "$PROJECT_ROOT/backend-config.txt" ]]; then
            log_info "Backend configuration:"
            cat "$PROJECT_ROOT/backend-config.txt"
        fi
        
        rm -f backend-setup.tfplan
    else
        log_error "Backend setup file not found: setup-backend.tf"
        exit 1
    fi
}

# Initialize Terraform
terraform_init() {
    local workspace=$1
    
    log_step "Initializing Terraform for workspace: $workspace"
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log_info "Running terraform init"
    terraform init
    
    # Create or select workspace
    if [[ "$workspace" != "default" ]]; then
        log_info "Managing workspace: $workspace"
        
        # Check if workspace exists
        if terraform workspace list | grep -q "$workspace"; then
            terraform workspace select "$workspace"
            log_info "Selected existing workspace: $workspace"
        else
            terraform workspace new "$workspace"
            log_success "Created new workspace: $workspace"
        fi
    fi
    
    log_success "Terraform initialization completed for workspace: $workspace"
}

# Generate plan
terraform_plan() {
    local workspace=$1
    local var_file_option=""
    local target_option=""
    
    if [[ -n "${VAR_FILE:-}" ]]; then
        var_file_option="-var-file=$VAR_FILE"
    fi
    
    if [[ -n "${TARGET:-}" ]]; then
        target_option="-target=$TARGET"
    fi
    
    log_step "Planning Terraform changes for workspace: $workspace"
    
    cd "$TERRAFORM_DIR"
    
    # Ensure we're in the right workspace
    if [[ "$workspace" != "default" ]]; then
        terraform workspace select "$workspace"
    fi
    
    # Generate plan
    local plan_file="${workspace}-$(date +%Y%m%d-%H%M%S).tfplan"
    
    log_info "Generating execution plan: $plan_file"
    
    # Run plan with appropriate options
    terraform plan \
        $var_file_option \
        $target_option \
        -out="$plan_file"
    
    log_success "Plan generated: $plan_file"
    
    # Save plan file path for apply
    echo "$plan_file" > ".terraform/.last_plan_$workspace"
}

# Apply changes
terraform_apply() {
    local workspace=$1
    local plan_file=""
    
    check_environment_protection "$workspace" "apply"
    
    log_step "Applying Terraform changes for workspace: $workspace"
    
    cd "$TERRAFORM_DIR"
    
    # Ensure we're in the right workspace
    if [[ "$workspace" != "default" ]]; then
        terraform workspace select "$workspace"
    fi
    
    # Check for existing plan file
    if [[ -f ".terraform/.last_plan_$workspace" ]]; then
        plan_file=$(cat ".terraform/.last_plan_$workspace")
        if [[ -f "$plan_file" ]]; then
            log_info "Using existing plan file: $plan_file"
        else
            log_warning "Plan file not found, generating new plan"
            terraform_plan "$workspace"
            plan_file=$(cat ".terraform/.last_plan_$workspace")
        fi
    else
        log_info "No plan file found, generating new plan"
        terraform_plan "$workspace"
        plan_file=$(cat ".terraform/.last_plan_$workspace")
    fi
    
    # Apply the plan
    if [[ "${AUTO_APPROVE:-false}" == "true" ]]; then
        terraform apply "$plan_file"
    else
        terraform apply "$plan_file"
    fi
    
    # Clean up plan file
    if [[ -f "$plan_file" ]]; then
        rm -f "$plan_file"
        rm -f ".terraform/.last_plan_$workspace"
    fi
    
    log_success "Apply completed for workspace: $workspace"
}

# Destroy infrastructure
terraform_destroy() {
    local workspace=$1
    
    check_environment_protection "$workspace" "destroy"
    
    log_step "Destroying Terraform infrastructure for workspace: $workspace"
    log_warning "This will DESTROY all resources in workspace: $workspace"
    
    if [[ "${AUTO_APPROVE:-false}" != "true" ]]; then
        echo -n "Type 'destroy' to confirm: "
        read -r confirmation
        if [[ "$confirmation" != "destroy" ]]; then
            log_info "Operation cancelled."
            exit 0
        fi
    fi
    
    cd "$TERRAFORM_DIR"
    
    # Ensure we're in the right workspace
    if [[ "$workspace" != "default" ]]; then
        terraform workspace select "$workspace"
    fi
    
    # Destroy infrastructure
    terraform destroy ${AUTO_APPROVE:+-auto-approve}
    
    log_success "Destroy completed for workspace: $workspace"
}

# Validate configuration
terraform_validate() {
    local workspace=$1
    
    log_step "Validating Terraform configuration for workspace: $workspace"
    
    cd "$TERRAFORM_DIR"
    
    # Format check
    log_info "Checking formatting"
    if ! terraform fmt -check=true -recursive; then
        log_warning "Files need formatting. Run: $0 $workspace format"
    fi
    
    # Validation
    log_info "Validating configuration"
    terraform validate
    
    log_success "Validation completed for workspace: $workspace"
}

# Format files
terraform_format() {
    log_step "Formatting Terraform files"
    
    cd "$TERRAFORM_DIR"
    
    terraform fmt -recursive
    
    log_success "Formatting completed"
}

# Show current state
terraform_show() {
    local workspace=$1
    
    log_step "Showing current state for workspace: $workspace"
    
    cd "$TERRAFORM_DIR"
    
    if [[ "$workspace" != "default" ]]; then
        terraform workspace select "$workspace"
    fi
    
    terraform show
}

# Show outputs
terraform_output() {
    local workspace=$1
    
    log_step "Showing outputs for workspace: $workspace"
    
    cd "$TERRAFORM_DIR"
    
    if [[ "$workspace" != "default" ]]; then
        terraform workspace select "$workspace"
    fi
    
    terraform output
}

# Workspace management
manage_workspace() {
    local action=$1
    
    cd "$TERRAFORM_DIR"
    
    case "$action" in
        list)
            terraform workspace list
            ;;
        show)
            terraform workspace show
            ;;
        *)
            log_error "Unknown workspace action: $action"
            log_info "Available actions: list, show"
            exit 1
            ;;
    esac
}

# State operations
manage_state() {
    local workspace=$1
    local action=$2
    shift 2
    
    log_step "State management for workspace: $workspace"
    
    cd "$TERRAFORM_DIR"
    
    if [[ "$workspace" != "default" ]]; then
        terraform workspace select "$workspace"
    fi
    
    case "$action" in
        list)
            terraform state list
            ;;
        show)
            terraform state show "$@"
            ;;
        mv)
            terraform state mv "$@"
            ;;
        rm)
            terraform state rm "$@"
            ;;
        pull)
            terraform state pull
            ;;
        push)
            terraform state push "$@"
            ;;
        *)
            log_error "Unknown state action: $action"
            log_info "Available actions: list, show, mv, rm, pull, push"
            exit 1
            ;;
    esac
}

# Import resources
terraform_import() {
    local workspace=$1
    local resource_address=$2
    local resource_id=$3
    
    log_step "Importing resource into workspace: $workspace"
    log_info "Resource: $resource_address"
    log_info "ID: $resource_id"
    
    cd "$TERRAFORM_DIR"
    
    if [[ "$workspace" != "default" ]]; then
        terraform workspace select "$workspace"
    fi
    
    terraform import "$resource_address" "$resource_id"
    
    log_success "Import completed"
}

# Migration from old configurations
migrate_from_old() {
    local workspace=$1
    local old_state_path=${2:-}
    
    log_step "Migrating from old configuration to workspace: $workspace"
    
    if [[ -z "$old_state_path" ]]; then
        log_error "Please provide the path to the old state file"
        log_info "Usage: $0 $workspace migrate /path/to/old/terraform.tfstate"
        exit 1
    fi
    
    if [[ ! -f "$old_state_path" ]]; then
        log_error "State file not found: $old_state_path"
        exit 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    if [[ "$workspace" != "default" ]]; then
        terraform workspace select "$workspace"
    fi
    
    log_info "Backing up old state"
    cp "$old_state_path" "$old_state_path.backup.$(date +%Y%m%d-%H%M%S)"
    
    log_info "Importing state to workspace: $workspace"
    terraform state push "$old_state_path"
    
    log_success "Migration completed"
    log_info "Please run 'terraform plan' to verify the migration"
}

# All workspaces operation
all_workspaces_operation() {
    local command=$1
    local workspaces=("dev" "staging" "prod")
    
    case "$command" in
        validate|format)
            log_step "Running $command for all workspaces"
            
            for workspace in "${workspaces[@]}"; do
                log_info "Processing workspace: $workspace"
                case "$command" in
                    validate)
                        terraform_validate "$workspace"
                        ;;
                    format)
                        terraform_format
                        ;;
                esac
            done
            ;;
        *)
            log_error "Command '$command' not supported for 'all' workspaces"
            log_info "Supported commands: validate, format"
            exit 1
            ;;
    esac
}

# Main function
main() {
    local workspace=${1:-}
    local command=${2:-}
    
    # Parse command line options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -y|--yes)
                AUTO_APPROVE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --var-file=*)
                VAR_FILE="${1#*=}"
                shift
                ;;
            --target=*)
                TARGET="${1#*=}"
                shift
                ;;
            *)
                if [[ -z "$workspace" ]]; then
                    workspace=$1
                elif [[ -z "$command" ]]; then
                    command=$1
                else
                    # Additional arguments passed to terraform
                    break
                fi
                shift
                ;;
        esac
    done
    
    # Validate inputs
    if [[ -z "$workspace" ]] || [[ -z "$command" ]]; then
        log_error "Missing required arguments"
        usage
        exit 1
    fi
    
    # Special case for backend setup
    if [[ "$workspace" == "backend" && "$command" == "setup" ]]; then
        setup_backend
        exit 0
    fi
    
    # Validate workspace
    validate_workspace "$workspace"
    
    # Handle 'all' workspace
    if [[ "$workspace" == "all" ]]; then
        all_workspaces_operation "$command"
        exit 0
    fi
    
    # Execute command
    case "$command" in
        init)
            terraform_init "$workspace"
            ;;
        plan)
            terraform_plan "$workspace"
            ;;
        apply)
            terraform_apply "$workspace"
            ;;
        destroy)
            terraform_destroy "$workspace"
            ;;
        validate)
            terraform_validate "$workspace"
            ;;
        format)
            terraform_format
            ;;
        show)
            terraform_show "$workspace"
            ;;
        output)
            terraform_output "$workspace"
            ;;
        workspace)
            manage_workspace "${3:-list}"
            ;;
        state)
            manage_state "$workspace" "${3:-list}" "${@:4}"
            ;;
        import)
            terraform_import "$workspace" "${3:-}" "${4:-}"
            ;;
        migrate)
            migrate_from_old "$workspace" "${3:-}"
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
