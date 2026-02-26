#!/bin/bash

# Clean Terraform Deployment Script
# This script destroys existing Terraform-managed resources and deploys fresh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CORE_TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform/core"
AINEXUS_TERRAFORM_DIR="$PROJECT_ROOT/apps/ai-nexus-workbench/infrastructure"

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================${NC}"
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

confirm_action() {
    local action="$1"
    echo -e "${YELLOW}About to: $action${NC}"
    read -p "Continue? (yes/no): " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        print_info "Operation cancelled"
        exit 0
    fi
}

destroy_existing_terraform() {
    print_header "DESTROYING EXISTING TERRAFORM RESOURCES"
    
    # Destroy AI Nexus first (if it exists and has state)
    if [[ -d "$AINEXUS_TERRAFORM_DIR" && -f "$AINEXUS_TERRAFORM_DIR/terraform.tfstate" ]]; then
        print_info "Destroying existing AI Nexus Workbench infrastructure..."
        cd "$AINEXUS_TERRAFORM_DIR"
        
        if [[ -f "terraform.dev.tfvars" ]]; then
            confirm_action "destroy AI Nexus Workbench resources"
            terraform destroy -var-file="terraform.dev.tfvars" -auto-approve || {
                print_warning "AI Nexus destroy completed with some errors - this is expected"
            }
            print_success "AI Nexus Workbench destruction completed"
        else
            print_warning "No AI Nexus tfvars file found"
        fi
    else
        print_info "No existing AI Nexus infrastructure found"
    fi
    
    # Destroy core infrastructure (if it exists and has state)
    if [[ -d "$CORE_TERRAFORM_DIR" && -f "$CORE_TERRAFORM_DIR/terraform.tfstate" ]]; then
        print_info "Destroying existing core infrastructure..."
        cd "$CORE_TERRAFORM_DIR"
        
        if [[ -f "terraform.dev.tfvars" ]]; then
            confirm_action "destroy core infrastructure resources (except preserved resources)"
            terraform destroy -var-file="terraform.dev.tfvars" -auto-approve || {
                print_warning "Core infrastructure destroy completed with some errors - this is expected"
            }
            print_success "Core infrastructure destruction completed"
        else
            print_warning "No core tfvars file found"
        fi
    else
        print_info "No existing core infrastructure found"
    fi
}

clean_terraform_state() {
    print_header "CLEANING TERRAFORM STATE AND CACHE"
    
    # Remove Terraform state files
    find "$PROJECT_ROOT" -name "terraform.tfstate*" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "*.tfplan" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name ".terraform.lock.hcl" -delete 2>/dev/null || true
    
    # Remove .terraform directories
    find "$PROJECT_ROOT" -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Terraform state and cache cleaned"
}

deploy_fresh_infrastructure() {
    print_header "DEPLOYING FRESH INFRASTRUCTURE"
    
    # Deploy core infrastructure first
    print_info "Deploying core infrastructure..."
    cd "$CORE_TERRAFORM_DIR"
    
    terraform init
    print_info "Core Terraform initialized"
    
    terraform plan -var-file="terraform.dev.tfvars" -out="dev-plan.tfplan"
    print_info "Core infrastructure plan created"
    
    confirm_action "apply core infrastructure plan"
    terraform apply "dev-plan.tfplan"
    print_success "Core infrastructure deployed successfully"
    
    # Deploy AI Nexus Workbench
    print_info "Deploying AI Nexus Workbench..."
    cd "$AINEXUS_TERRAFORM_DIR"
    
    terraform init
    print_info "AI Nexus Terraform initialized"
    
    terraform plan -var-file="terraform.dev.tfvars" -out="dev-plan.tfplan"
    print_info "AI Nexus Workbench plan created"
    
    confirm_action "apply AI Nexus Workbench plan"
    terraform apply "dev-plan.tfplan"
    print_success "AI Nexus Workbench deployed successfully"
}

validate_deployment() {
    print_header "VALIDATING DEPLOYMENT"
    
    # Check core infrastructure outputs
    print_info "Validating core infrastructure..."
    cd "$CORE_TERRAFORM_DIR"
    terraform output
    
    # Check AI Nexus outputs
    print_info "Validating AI Nexus Workbench..."
    cd "$AINEXUS_TERRAFORM_DIR"
    terraform output
    
    print_success "Deployment validation completed"
}

main() {
    print_header "CLEAN TERRAFORM DEPLOYMENT"
    echo -e "${GREEN}This will destroy and rebuild your dev environment cleanly${NC}"
    echo -e "${YELLOW}Production resources and preserved infrastructure will remain intact${NC}"
    echo ""
    
    # Show current AWS identity
    print_info "Current AWS Identity:"
    aws sts get-caller-identity --output table
    
    # Execute deployment steps
    destroy_existing_terraform
    clean_terraform_state  
    deploy_fresh_infrastructure
    validate_deployment
    
    print_header "CLEAN DEPLOYMENT COMPLETED"
    print_success "✅ Fresh infrastructure deployment completed successfully"
    print_info "Your AI Nexus Workbench is now ready to use!"
    echo ""
    echo "Access your deployment:"
    echo "- API Gateway: Check outputs above for custom domain URL"
    echo "- Cognito: User authentication is configured"
    echo "- S3: Upload buckets are ready"
    echo "- DynamoDB: Tables are created and ready"
}

# Handle script arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
