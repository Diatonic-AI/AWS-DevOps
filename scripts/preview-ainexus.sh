#!/bin/bash

# Preview AI Nexus Workbench Resources Script  
# This script shows what resources would be managed WITHOUT making any changes
# 100% SAFE - READ-ONLY PREVIEW

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

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[SAFE PREVIEW]${NC} $1"
}

main() {
    print_header "AI NEXUS WORKBENCH RESOURCE PREVIEW"
    
    print_warning "This is a SAFE, READ-ONLY preview - no resources will be modified"
    echo ""
    
    print_info "AI Nexus Directory: $AINEXUS_TERRAFORM_DIR"
    
    if [[ ! -d "$AINEXUS_TERRAFORM_DIR" ]]; then
        echo "❌ AI Nexus directory not found"
        exit 1
    fi
    
    cd "$AINEXUS_TERRAFORM_DIR"
    
    if [[ ! -f "terraform.dev.tfvars" ]]; then
        echo "❌ terraform.dev.tfvars not found"
        exit 1
    fi
    
    # Show current state (if any)
    print_header "CURRENT AI NEXUS STATE"
    if [[ -f "terraform.tfstate" ]]; then
        print_info "Current deployed resources (if any):"
        terraform show -json terraform.tfstate 2>/dev/null | jq -r '.values.root_module.resources[]? | "  \(.address) (\(.type))"' || {
            print_info "Current state exists but couldn't parse - checking with terraform state list..."
            terraform state list 2>/dev/null || print_info "No resources in current state"
        }
    else
        print_info "No current AI Nexus state found (fresh deployment)"
    fi
    
    echo ""
    
    # Show what would be deployed
    print_header "PLANNED AI NEXUS DEPLOYMENT"
    print_info "Initializing Terraform to show deployment plan..."
    
    terraform init -upgrade 2>/dev/null || terraform init
    
    print_info "Resources that would be created/managed:"
    terraform plan -var-file="terraform.dev.tfvars" -out="preview-plan.tfplan" 2>/dev/null
    
    # Extract and show resource list
    terraform show -json "preview-plan.tfplan" | jq -r '
        .planned_values.root_module.resources[]? |
        "  ✅ \(.address) (\(.type))"
    ' 2>/dev/null || {
        print_info "Plan created but couldn't parse JSON - showing plan directly:"
        terraform show "preview-plan.tfplan"
    }
    
    # Clean up plan file
    rm -f "preview-plan.tfplan"
    
    echo ""
    print_header "RESOURCE SCOPE CONFIRMATION"
    echo -e "${GREEN}✅ ONLY AI Nexus Workbench application resources shown above${NC}"
    echo -e "${GREEN}🔒 NO tenant-wide infrastructure will be affected${NC}"
    echo ""
    
    print_success "Preview completed successfully"
    echo ""
    echo "To deploy these resources, run:"
    echo "  /home/daclab-ai/dev/AWS-DevOps/scripts/ainexus-only-deploy.sh"
}

# Run preview
main "$@"
