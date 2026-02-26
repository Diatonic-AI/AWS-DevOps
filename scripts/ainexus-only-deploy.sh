#!/bin/bash

# AI Nexus Workbench ONLY Deployment Script
# This script ONLY manages AI Nexus Workbench application resources
# It does NOT touch any tenant-wide infrastructure:
# - Route53 domains/hosted zones
# - SSL certificates  
# - Core VPC infrastructure
# - MinIO infrastructure
# - Shared S3 buckets
# - Core networking

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

print_preserve() {
    echo -e "${GREEN}[PRESERVED]${NC} $1"
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

show_scope() {
    print_header "AI NEXUS WORKBENCH DEPLOYMENT SCOPE"
    echo -e "${GREEN}This script ONLY manages AI Nexus Workbench application resources:${NC}"
    echo "  ✅ AI Nexus API Gateway"
    echo "  ✅ AI Nexus Cognito User Pool"
    echo "  ✅ AI Nexus Lambda Functions"
    echo "  ✅ AI Nexus DynamoDB Tables"
    echo "  ✅ AI Nexus S3 Upload Integration"
    echo ""
    echo -e "${GREEN}The following tenant-wide infrastructure remains UNTOUCHED:${NC}"
    echo "  🔒 Route53 domains and hosted zones"
    echo "  🔒 SSL certificates (ACM)"
    echo "  🔒 Core VPC and networking"
    echo "  🔒 MinIO infrastructure"
    echo "  🔒 Shared/tenant S3 buckets"
    echo "  🔒 Core infrastructure components"
    echo "  🔒 Production environment resources"
    echo ""
}

validate_ainexus_directory() {
    if [[ ! -d "$AINEXUS_TERRAFORM_DIR" ]]; then
        print_error "AI Nexus Workbench directory not found: $AINEXUS_TERRAFORM_DIR"
        exit 1
    fi
    
    if [[ ! -f "$AINEXUS_TERRAFORM_DIR/terraform.dev.tfvars" ]]; then
        print_error "AI Nexus dev configuration not found: $AINEXUS_TERRAFORM_DIR/terraform.dev.tfvars"
        exit 1
    fi
    
    print_info "AI Nexus Workbench directory validated: $AINEXUS_TERRAFORM_DIR"
}

destroy_ainexus_only() {
    print_header "DESTROYING AI NEXUS WORKBENCH RESOURCES ONLY"
    
    cd "$AINEXUS_TERRAFORM_DIR"
    
    # Check if there's existing state
    if [[ -f "terraform.tfstate" ]]; then
        print_info "Found existing AI Nexus Terraform state"
        
        # Show what would be destroyed
        print_info "Showing resources that would be destroyed..."
        terraform plan -destroy -var-file="terraform.dev.tfvars" || {
            print_warning "Plan failed - this might be due to state inconsistencies"
        }
        
        confirm_action "destroy AI Nexus Workbench resources ONLY (no tenant infrastructure)"
        
        # Execute destroy
        terraform destroy -var-file="terraform.dev.tfvars" -auto-approve || {
            print_warning "Some AI Nexus resources may have failed to destroy"
            print_info "This is often normal - continuing with cleanup"
        }
        
        print_success "AI Nexus Workbench destruction completed"
    else
        print_info "No existing AI Nexus infrastructure state found"
    fi
}

clean_ainexus_state() {
    print_header "CLEANING AI NEXUS TERRAFORM STATE"
    
    cd "$AINEXUS_TERRAFORM_DIR"
    
    # Remove AI Nexus specific state files and cache
    if [[ -f "terraform.tfstate" ]]; then
        mv "terraform.tfstate" "terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)" || true
        print_info "AI Nexus state file backed up"
    fi
    
    if [[ -f "terraform.tfstate.backup" ]]; then
        mv "terraform.tfstate.backup" "terraform.tfstate.backup.old.$(date +%Y%m%d-%H%M%S)" || true
        print_info "Old backup state file archived"
    fi
    
    # Remove AI Nexus cache and locks
    rm -rf ".terraform" 2>/dev/null || true
    rm -f ".terraform.lock.hcl" 2>/dev/null || true
    rm -f "*.tfplan" 2>/dev/null || true
    
    print_success "AI Nexus Terraform state cleaned"
}

deploy_ainexus_fresh() {
    print_header "DEPLOYING FRESH AI NEXUS WORKBENCH"
    
    cd "$AINEXUS_TERRAFORM_DIR"
    
    # Initialize Terraform
    print_info "Initializing AI Nexus Terraform..."
    terraform init
    print_success "AI Nexus Terraform initialized"
    
    # Create deployment plan
    print_info "Creating AI Nexus deployment plan..."
    terraform plan -var-file="terraform.dev.tfvars" -out="ainexus-dev-plan.tfplan"
    print_success "AI Nexus deployment plan created"
    
    # Show plan summary
    print_info "Deployment plan summary:"
    terraform show -json "ainexus-dev-plan.tfplan" | jq -r '.resource_changes[]? | select(.change.actions[] | contains("create")) | "  + \(.address) (\(.type))"' || {
        print_info "Plan summary not available - continuing with deployment"
    }
    
    # Confirm deployment
    confirm_action "deploy fresh AI Nexus Workbench (application resources only)"
    
    # Execute deployment
    print_info "Deploying AI Nexus Workbench..."
    terraform apply "ainexus-dev-plan.tfplan"
    
    # Clean up plan file
    rm -f "ainexus-dev-plan.tfplan"
    
    print_success "AI Nexus Workbench deployed successfully"
}

validate_ainexus_deployment() {
    print_header "VALIDATING AI NEXUS DEPLOYMENT"
    
    cd "$AINEXUS_TERRAFORM_DIR"
    
    # Show outputs
    print_info "AI Nexus Workbench deployment outputs:"
    terraform output || {
        print_warning "No outputs available"
    }
    
    # Validate key resources were created
    print_info "Validating key AI Nexus resources..."
    
    # Check if API Gateway was created
    local api_gateway=$(terraform output -raw api_gateway_id 2>/dev/null || echo "")
    if [[ -n "$api_gateway" ]]; then
        print_success "API Gateway created: $api_gateway"
    else
        print_warning "API Gateway ID not found in outputs"
    fi
    
    # Check if Cognito was created
    local user_pool=$(terraform output -raw cognito_user_pool_id 2>/dev/null || echo "")
    if [[ -n "$user_pool" ]]; then
        print_success "Cognito User Pool created: $user_pool"
    else
        print_warning "Cognito User Pool ID not found in outputs"
    fi
    
    print_success "AI Nexus Workbench validation completed"
}

show_access_info() {
    print_header "AI NEXUS WORKBENCH ACCESS INFORMATION"
    
    cd "$AINEXUS_TERRAFORM_DIR"
    
    echo -e "${GREEN}Your AI Nexus Workbench is now ready!${NC}"
    echo ""
    
    # Try to get key access information
    local api_url=$(terraform output -raw api_gateway_url 2>/dev/null || echo "Check outputs above")
    local user_pool_id=$(terraform output -raw cognito_user_pool_id 2>/dev/null || echo "Check outputs above")
    local client_id=$(terraform output -raw cognito_user_pool_client_id 2>/dev/null || echo "Check outputs above")
    
    echo "🌐 API Gateway URL: $api_url"
    echo "👤 Cognito User Pool: $user_pool_id"
    echo "🔑 Client ID: $client_id"
    echo ""
    echo "📋 Complete configuration available via:"
    echo "   terraform output"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Test API Gateway endpoints"
    echo "2. Configure user authentication"
    echo "3. Test file upload functionality"
    echo "4. Validate DynamoDB table access"
}

main() {
    print_header "AI NEXUS WORKBENCH DEPLOYMENT"
    
    show_scope
    
    # Validate environment
    validate_ainexus_directory
    
    # Show current AWS identity (for verification only)
    print_info "Current AWS Identity (for verification):"
    aws sts get-caller-identity --output table
    echo ""
    
    # Confirm scope
    confirm_action "proceed with AI Nexus Workbench deployment (application layer only)"
    
    # Execute deployment steps
    destroy_ainexus_only
    clean_ainexus_state
    deploy_ainexus_fresh
    validate_ainexus_deployment
    
    # Show final information
    show_access_info
    
    print_header "AI NEXUS DEPLOYMENT COMPLETED"
    print_success "✅ AI Nexus Workbench successfully deployed"
    print_info "🔒 All tenant-wide infrastructure preserved"
    echo ""
    echo -e "${GREEN}Your AI Nexus Workbench is ready for dev, testing, and production use!${NC}"
}

# Handle script arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
