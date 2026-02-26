#!/bin/bash

# Cloudflare Setup Script for Unified AWS-DevOps Terraform
# Usage: ./setup-cloudflare.sh [options]

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_NAME="cloudflare"
TERRAFORM_DIR="$SCRIPT_DIR"

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
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

# Show help
show_help() {
    cat << EOF
Cloudflare Setup Script for Unified AWS-DevOps Terraform

USAGE:
    $0 [OPTIONS] [ACTION]

OPTIONS:
    -t, --token TOKEN    Cloudflare API token (required)
    -e, --env ENV       Environment (dev, staging, prod) [default: dev]
    -d, --dry-run       Show plan without applying
    -f, --force         Apply without confirmation
    -h, --help          Show this help message

ACTIONS:
    init      Initialize Terraform and create workspace
    plan      Show execution plan
    apply     Apply Cloudflare configuration
    destroy   Destroy Cloudflare resources
    status    Show current status
    migrate   Show migration instructions

EXAMPLES:
    # Initialize and apply with interactive token input
    $0 init apply

    # Plan with specific token and environment
    $0 --token "your_token_here" --env prod plan

    # Apply with dry run first
    $0 --token "your_token_here" --dry-run apply

ENVIRONMENT VARIABLES:
    CLOUDFLARE_API_TOKEN     - Cloudflare API token
    TF_WORKSPACE             - Terraform workspace name
    AWS_PROFILE              - AWS profile to use

PREREQUISITES:
    1. Domain 'diatonic.ai' must be added to Cloudflare dashboard
    2. Cloudflare API token with Zone:Edit permissions
    3. Terraform >= 1.5.0 installed
    4. AWS credentials configured

For more information, see: cloudflare-dns-migration.md
EOF
}

# Parse command line arguments
parse_args() {
    CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
    CLOUDFLARE_API_KEY="${CLOUDFLARE_API_KEY:-}"
    CLOUDFLARE_EMAIL="${CLOUDFLARE_EMAIL:-}"
    ENVIRONMENT="dev"
    DRY_RUN=false
    FORCE_APPLY=false
    ACTIONS=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--token)
                CLOUDFLARE_API_TOKEN="$2"
                shift 2
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE_APPLY=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            init|plan|apply|destroy|status|migrate)
                ACTIONS+=("$1")
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Default action if none specified
    if [[ ${#ACTIONS[@]} -eq 0 ]]; then
        ACTIONS=("status")
    fi

    export CLOUDFLARE_API_TOKEN
    export CLOUDFLARE_API_KEY
    export CLOUDFLARE_EMAIL
    export ENVIRONMENT
}

# Validate prerequisites
validate_prerequisites() {
    log_section "Validating Prerequisites"

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_success "Terraform version: $tf_version"

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        log_info "Please run: aws configure"
        exit 1
    fi
    
    local aws_account=$(aws sts get-caller-identity --query Account --output text)
    local aws_region=$(aws configure get region)
    log_success "AWS account: $aws_account, region: $aws_region"

    # Check Cloudflare authentication (either API token or API key + email)
    if [[ -z "$CLOUDFLARE_API_TOKEN" && -z "$CLOUDFLARE_API_KEY" ]]; then
        log_warn "Cloudflare API credentials not provided"
        echo "Choose authentication method:"
        echo "1. API Token (recommended)"
        echo "2. Global API Key + Email (legacy)"
        read -p "Enter choice (1 or 2): " auth_choice
        
        if [[ "$auth_choice" == "1" ]]; then
            read -s -p "Enter Cloudflare API token: " CLOUDFLARE_API_TOKEN
            echo
            export CLOUDFLARE_API_TOKEN
        else
            read -s -p "Enter Cloudflare Global API Key: " CLOUDFLARE_API_KEY
            echo
            read -p "Enter Cloudflare account email: " CLOUDFLARE_EMAIL
            export CLOUDFLARE_API_KEY
            export CLOUDFLARE_EMAIL
        fi
    fi

    # Validate Cloudflare credentials (prioritize API Key if provided)
    if [[ -n "$CLOUDFLARE_API_KEY" && -n "$CLOUDFLARE_EMAIL" ]]; then
        log_info "Validating Global API Key..."
        if ! curl -s -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
             -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
             "https://api.cloudflare.com/client/v4/user" | \
             jq -e '.success == true' &> /dev/null; then
            log_error "Invalid Cloudflare API key or email"
            exit 1
        fi
        log_success "Cloudflare Global API Key validated"
    elif [[ -n "$CLOUDFLARE_API_TOKEN" ]]; then
        log_info "Validating API Token..."
        if ! curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
             "https://api.cloudflare.com/client/v4/user/tokens/verify" | \
             jq -e '.success == true' &> /dev/null; then
            log_error "Invalid Cloudflare API token"
            exit 1
        fi
        log_success "Cloudflare API token validated"
    else
        log_error "Neither API Token nor API Key + Email provided"
        exit 1
    fi

    # Check required tools
    for tool in jq curl; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is required but not installed"
            exit 1
        fi
    done

    log_success "All prerequisites validated"
}

# Initialize Terraform
terraform_init() {
    log_section "Initializing Terraform"
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log_info "Running terraform init..."
    terraform init -upgrade
    
    # Create or select workspace
    local existing_workspaces=$(terraform workspace list)
    if echo "$existing_workspaces" | grep -q "^\*\?\s*$WORKSPACE_NAME$"; then
        log_info "Switching to existing workspace: $WORKSPACE_NAME"
        terraform workspace select "$WORKSPACE_NAME"
    else
        log_info "Creating new workspace: $WORKSPACE_NAME"
        terraform workspace new "$WORKSPACE_NAME"
    fi
    
    log_success "Terraform initialized with workspace: $(terraform workspace show)"
}

# Create terraform.tfvars file
create_tfvars() {
    log_section "Creating Terraform Variables File"
    
    local tfvars_file="terraform.tfvars"
    
    cat > "$tfvars_file" << EOF
# Cloudflare Configuration for Unified Terraform
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Enable Cloudflare
enable_cloudflare = true

# Cloudflare Authentication (loaded from environment)
# Use EITHER:
# cloudflare_api_token = "provided via TF_VAR_cloudflare_api_token"
# OR:
# cloudflare_api_key = "provided via TF_VAR_cloudflare_api_key"
# cloudflare_email = "provided via TF_VAR_cloudflare_email"

# Domain Configuration
domain_name = "diatonic.ai"

# Cloudflare Zone and Account (pre-configured)
cloudflare_zone_id    = "f889715fdbadcf662ea496b8e40ee6eb"
cloudflare_account_id = "35043351f8c199237f5ebd11f4a27c15"

# AWS CloudFront Integration
default_cloudfront_domain = "d34iz6fjitwuax.cloudfront.net"

# Project Configuration
project_name = "aws-devops"
aws_region   = "us-east-2"

# Common Tags
common_tags = {
  Project     = "AWS-DevOps"
  Environment = "$ENVIRONMENT"
  ManagedBy   = "Terraform-Unified"
  Domain      = "diatonic.ai"
  CDN         = "Cloudflare"
  Repository  = "AWS-DevOps"
}

# Notification
notification_email = null # Add your email for alerts

# Feature Flags
feature_flags = {
  enable_cloudtrail   = true
  enable_config       = false
  enable_guardduty    = false
  enable_security_hub = false
  enable_cost_alerts  = true
  enable_multi_az     = true
}
EOF

    log_success "Created $tfvars_file"
    log_info "Review and customize the variables as needed"
}

# Run terraform plan
terraform_plan() {
    log_section "Planning Terraform Changes"
    
    cd "$TERRAFORM_DIR"
    
    # Set Terraform variables based on authentication method
    if [[ -n "$CLOUDFLARE_API_TOKEN" ]]; then
        export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
        # Set unused variables to empty to prevent conflicts
        export TF_VAR_cloudflare_api_key=""
        export TF_VAR_cloudflare_email=""
    elif [[ -n "$CLOUDFLARE_API_KEY" && -n "$CLOUDFLARE_EMAIL" ]]; then
        export TF_VAR_cloudflare_api_key="$CLOUDFLARE_API_KEY"
        export TF_VAR_cloudflare_email="$CLOUDFLARE_EMAIL"
        # Set unused variable to empty to prevent conflicts
        export TF_VAR_cloudflare_api_token=""
    fi
    
    local plan_file="cloudflare-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).tfplan"
    
    log_info "Creating execution plan..."
    terraform plan \
        -var-file="terraform.tfvars" \
        -out="$plan_file" \
        -detailed-exitcode || {
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            log_info "Changes detected - plan saved to: $plan_file"
            export TERRAFORM_PLAN_FILE="$plan_file"
            return 0
        else
            log_error "Terraform plan failed with exit code: $exit_code"
            return $exit_code
        fi
    }
    
    log_success "No changes detected"
    export TERRAFORM_PLAN_FILE=""
}

# Apply terraform changes
terraform_apply() {
    log_section "Applying Terraform Changes"
    
    cd "$TERRAFORM_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - Would apply Terraform changes"
        return 0
    fi
    
    # Set Terraform variables based on authentication method
    if [[ -n "$CLOUDFLARE_API_TOKEN" ]]; then
        export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
        # Set unused variables to empty to prevent conflicts
        export TF_VAR_cloudflare_api_key=""
        export TF_VAR_cloudflare_email=""
    elif [[ -n "$CLOUDFLARE_API_KEY" && -n "$CLOUDFLARE_EMAIL" ]]; then
        export TF_VAR_cloudflare_api_key="$CLOUDFLARE_API_KEY"
        export TF_VAR_cloudflare_email="$CLOUDFLARE_EMAIL"
        # Set unused variable to empty to prevent conflicts
        export TF_VAR_cloudflare_api_token=""
    fi
    
    # Check if we have a plan file
    if [[ -n "${TERRAFORM_PLAN_FILE:-}" && -f "$TERRAFORM_PLAN_FILE" ]]; then
        if [[ "$FORCE_APPLY" != "true" ]]; then
            echo
            log_warn "About to apply Terraform changes to Cloudflare DNS configuration"
            log_info "This will:"
            log_info "  ✅ Create DNS records for diatonic.ai and all subdomains"
            log_info "  ⚙️  Configure SSL/TLS, performance, and security settings"
            log_info "  🔒 Set up firewall rules and rate limiting"
            log_info "  📊 Configure caching and page rules"
            echo
            read -p "Do you want to continue? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled by user"
                return 1
            fi
        fi
        
        log_info "Applying plan: $TERRAFORM_PLAN_FILE"
        terraform apply "$TERRAFORM_PLAN_FILE"
    else
        log_info "No plan file available, running apply directly..."
        terraform apply -var-file="terraform.tfvars" -auto-approve
    fi
    
    log_success "Terraform apply completed successfully!"
}

# Show current status
show_status() {
    log_section "Current Status"
    
    cd "$TERRAFORM_DIR"
    
    local current_workspace=$(terraform workspace show)
    log_info "Current workspace: $current_workspace"
    
    # Check if Cloudflare is enabled in current state
    if terraform show -json 2>/dev/null | jq -e '.values.root_module.child_modules[] | select(.address == "module.cloudflare")' &> /dev/null; then
        log_success "Cloudflare module is deployed"
        
        # Show DNS records if available
        log_info "Fetching DNS record status..."
        local dns_records=$(terraform output -json cloudflare_dns_records 2>/dev/null || echo "null")
        
        if [[ "$dns_records" != "null" ]]; then
            echo -e "\n${GREEN}📋 DNS Records Status:${NC}"
            echo "$dns_records" | jq -r 'to_entries[] | "  ✅ \(.key): \(.value)"'
        fi
        
        # Show nameservers
        local nameservers=$(terraform output -json cloudflare_nameservers 2>/dev/null || echo "null")
        if [[ "$nameservers" != "null" ]]; then
            echo -e "\n${GREEN}🌐 Cloudflare Nameservers:${NC}"
            echo "$nameservers" | jq -r '.[] | "  • \(.)"'
        fi
    else
        log_warn "Cloudflare module is not deployed in current workspace"
    fi
    
    # Check environment variables
    echo -e "\n${CYAN}Environment Configuration:${NC}"
    echo "  • Environment: ${ENVIRONMENT}"
    echo "  • API Token: ${CLOUDFLARE_API_TOKEN:+[CONFIGURED]}${CLOUDFLARE_API_TOKEN:-[NOT SET]}"
    echo "  • Workspace: $current_workspace"
}

# Show migration instructions
show_migration_instructions() {
    log_section "DNS Migration Instructions"
    
    cd "$TERRAFORM_DIR"
    
    # Check if Cloudflare is deployed
    if ! terraform show -json 2>/dev/null | jq -e '.values.root_module.child_modules[] | select(.address == "module.cloudflare")' &> /dev/null; then
        log_error "Cloudflare module is not deployed yet"
        log_info "Run: $0 --token YOUR_TOKEN apply"
        return 1
    fi
    
    local migration_instructions=$(terraform output -json dns_migration_instructions 2>/dev/null || echo "null")
    
    if [[ "$migration_instructions" != "null" ]]; then
        echo "$migration_instructions" | jq -r '
            "✅ " + .step_1,
            "",
            "🔄 " + .step_2,
            "   Current Route 53 nameservers:",
            (.current_nameservers[] | "     • " + .),
            "",
            "   New Cloudflare nameservers:",
            (.new_nameservers[] | "     • " + .),
            "",
            "⏱️  " + .step_3,
            "🧪 " + .step_4,
            "📊 " + .step_5
        '
    else
        log_error "Migration instructions not available"
    fi
    
    echo -e "\n${PURPLE}📚 Additional Resources:${NC}"
    echo "  • Migration Guide: cloudflare-dns-migration.md"
    echo "  • Dashboard: https://dash.cloudflare.com/2ce1478eaf8042eaa3bee715d34301b9"
    echo "  • Analytics: https://dash.cloudflare.com/2ce1478eaf8042eaa3bee715d34301b9/analytics"
}

# Destroy resources
terraform_destroy() {
    log_section "Destroying Cloudflare Resources"
    
    cd "$TERRAFORM_DIR"
    
    log_warn "⚠️  WARNING: This will destroy all Cloudflare DNS records and configuration!"
    log_info "This action will:"
    log_info "  ❌ Remove all DNS records for diatonic.ai"
    log_info "  ❌ Delete SSL/TLS configuration"
    log_info "  ❌ Remove firewall rules and page rules"
    echo
    
    if [[ "$FORCE_APPLY" != "true" ]]; then
        read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
        if [[ "$REPLY" != "yes" ]]; then
            log_info "Destroy operation cancelled"
            return 1
        fi
    fi
    
    # Set Terraform variables based on authentication method
    if [[ -n "$CLOUDFLARE_API_TOKEN" ]]; then
        export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
        # Set unused variables to empty to prevent conflicts
        export TF_VAR_cloudflare_api_key=""
        export TF_VAR_cloudflare_email=""
    elif [[ -n "$CLOUDFLARE_API_KEY" && -n "$CLOUDFLARE_EMAIL" ]]; then
        export TF_VAR_cloudflare_api_key="$CLOUDFLARE_API_KEY"
        export TF_VAR_cloudflare_email="$CLOUDFLARE_EMAIL"
        # Set unused variable to empty to prevent conflicts
        export TF_VAR_cloudflare_api_token=""
    fi
    
    terraform destroy -var-file="terraform.tfvars" -auto-approve
    
    log_success "Cloudflare resources destroyed"
}

# Main execution
main() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              Cloudflare Setup for AWS-DevOps                    ║"
    echo "║                  Unified Terraform Configuration                 ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    parse_args "$@"
    
    for action in "${ACTIONS[@]}"; do
        case "$action" in
            init)
                validate_prerequisites
                terraform_init
                create_tfvars
                ;;
            plan)
                validate_prerequisites
                terraform_plan
                ;;
            apply)
                validate_prerequisites
                if [[ ! -f "terraform.tfvars" ]]; then
                    create_tfvars
                fi
                terraform_plan
                terraform_apply
                show_migration_instructions
                ;;
            destroy)
                validate_prerequisites
                terraform_destroy
                ;;
            status)
                show_status
                ;;
            migrate)
                show_migration_instructions
                ;;
            *)
                log_error "Unknown action: $action"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_section "Setup Complete"
    log_success "Cloudflare setup operations completed successfully!"
}

# Run main function
main "$@"
