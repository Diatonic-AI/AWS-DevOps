#!/bin/bash

# Terraform Deployment Script
# Usage: ./deploy.sh <environment> <action>
# Example: ./deploy.sh dev plan
# Example: ./deploy.sh prod apply

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/core"
VALID_ENVIRONMENTS=("dev" "staging" "prod")
VALID_ACTIONS=("init" "plan" "apply" "destroy" "validate" "fmt" "output" "show" "refresh" "plan-apply")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_usage() {
    echo -e "${BLUE}Usage: $0 <environment> <action> [additional_args]${NC}"
    echo ""
    echo -e "${YELLOW}Environments:${NC}"
    printf '  %s\n' "${VALID_ENVIRONMENTS[@]}"
    echo ""
    echo -e "${YELLOW}Actions:${NC}"
    echo "  init     - Initialize Terraform"
    echo "  plan         - Show execution plan (saves to plan file)"
    echo "  apply        - Apply changes (from plan file if exists)"
    echo "  plan-apply   - Plan and apply in one step (recommended)"
    echo "  destroy      - Destroy infrastructure"
    echo "  validate     - Validate configuration"
    echo "  fmt          - Format configuration files"
    echo "  output       - Show output values"
    echo "  show         - Show current state"
    echo "  refresh      - Refresh state"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 dev plan"
    echo "  $0 prod apply"
    echo "  $0 dev destroy --auto-approve"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

validate_environment() {
    local env=$1
    for valid_env in "${VALID_ENVIRONMENTS[@]}"; do
        if [[ "$env" == "$valid_env" ]]; then
            return 0
        fi
    done
    return 1
}

validate_action() {
    local action=$1
    for valid_action in "${VALID_ACTIONS[@]}"; do
        if [[ "$action" == "$valid_action" ]]; then
            return 0
        fi
    done
    return 1
}

check_prerequisites() {
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed or not in PATH"
        exit 1
    fi

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid"
        exit 1
    fi

    # Check if terraform directory exists
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        print_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
}

run_terraform() {
    local environment=$1
    local action=$2
    shift 2
    local additional_args=("$@")

    local var_file="terraform.${environment}.tfvars"
    local var_file_path="${TERRAFORM_DIR}/${var_file}"
    local plan_file="${environment}-plan.tfplan"
    local plan_file_path="${TERRAFORM_DIR}/${plan_file}"

    # Change to terraform directory
    cd "$TERRAFORM_DIR"

    # Check if variable file exists
    if [[ ! -f "$var_file_path" ]]; then
        print_error "Variable file not found: $var_file_path"
        exit 1
    fi

    print_info "Running Terraform $action for environment: $environment"
    print_info "Working directory: $TERRAFORM_DIR"
    print_info "Variable file: $var_file"

    case "$action" in
        "init")
            terraform init "${additional_args[@]}"
            ;;
        "plan")
            # Save plan to file for consistency
            print_info "Creating plan file: $plan_file"
            terraform plan -var-file="$var_file" -out="$plan_file" "${additional_args[@]}"
            print_success "Plan saved to: $plan_file_path"
            print_info "To apply this exact plan, run: terraform apply \"$plan_file\" or use: $0 $environment apply"
            ;;
        "apply")
            # Check if plan file exists and use it, otherwise create new plan
            if [[ -f "$plan_file_path" ]]; then
                print_info "Found existing plan file: $plan_file"
                print_info "Applying saved plan (no confirmation needed - plan already approved)"
                terraform apply "$plan_file"
                # Remove plan file after successful apply
                rm -f "$plan_file"
                print_info "Plan file removed after successful apply"
            else
                print_warning "No plan file found. Creating new plan and applying..."
                # Add confirmation prompt for apply unless --auto-approve is specified
                if [[ ! " ${additional_args[*]} " =~ " --auto-approve " ]]; then
                    print_warning "This will apply changes to $environment environment"
                    read -p "Are you sure you want to continue? (yes/no): " confirmation
                    if [[ "$confirmation" != "yes" ]]; then
                        print_info "Operation cancelled"
                        exit 0
                    fi
                fi
                terraform apply -var-file="$var_file" "${additional_args[@]}"
            fi
            ;;
        "plan-apply")
            print_info "Creating plan file: $plan_file"
            terraform plan -var-file="$var_file" -out="$plan_file" "${additional_args[@]}"
            print_success "Plan created successfully"
            
            # Add confirmation prompt unless --auto-approve is specified
            if [[ ! " ${additional_args[*]} " =~ " --auto-approve " ]]; then
                print_warning "This will apply the above changes to $environment environment"
                read -p "Are you sure you want to continue? (yes/no): " confirmation
                if [[ "$confirmation" != "yes" ]]; then
                    print_info "Operation cancelled - plan file saved for later use"
                    print_info "To apply later, run: $0 $environment apply"
                    exit 0
                fi
            fi
            
            print_info "Applying plan..."
            terraform apply "$plan_file"
            # Remove plan file after successful apply
            rm -f "$plan_file"
            print_info "Plan file removed after successful apply"
            ;;
        "destroy")
            print_warning "This will DESTROY infrastructure in $environment environment"
            if [[ ! " ${additional_args[*]} " =~ " --auto-approve " ]]; then
                read -p "Are you ABSOLUTELY sure you want to continue? Type 'destroy' to confirm: " confirmation
                if [[ "$confirmation" != "destroy" ]]; then
                    print_info "Operation cancelled"
                    exit 0
                fi
            fi
            terraform destroy -var-file="$var_file" "${additional_args[@]}"
            ;;
        "validate")
            terraform validate "${additional_args[@]}"
            ;;
        "fmt")
            terraform fmt -recursive "${additional_args[@]}"
            ;;
        "output")
            terraform output "${additional_args[@]}"
            ;;
        "show")
            # Check if there's a plan file to show, otherwise show state
            if [[ -f "$plan_file_path" ]]; then
                print_info "Showing saved plan: $plan_file"
                terraform show "$plan_file" "${additional_args[@]}"
            else
                terraform show "${additional_args[@]}"
            fi
            ;;
        "refresh")
            terraform refresh -var-file="$var_file" "${additional_args[@]}"
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        print_success "Terraform $action completed successfully"
    else
        print_error "Terraform $action failed"
        exit 1
    fi
}

# Main script
main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        print_error "Missing required arguments"
        print_usage
        exit 1
    fi

    local environment=$1
    local action=$2
    shift 2
    local additional_args=("$@")

    # Validate inputs
    if ! validate_environment "$environment"; then
        print_error "Invalid environment: $environment"
        print_usage
        exit 1
    fi

    if ! validate_action "$action"; then
        print_error "Invalid action: $action"
        print_usage
        exit 1
    fi

    # Check prerequisites
    check_prerequisites

    # Show current AWS identity
    print_info "Current AWS Identity:"
    aws sts get-caller-identity --output table

    # Run terraform command
    run_terraform "$environment" "$action" "${additional_args[@]}"
}

# Handle script arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
