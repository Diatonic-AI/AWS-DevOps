#!/usr/bin/env bash
# Simple Import Approach - Phase by Phase
# This script imports resources in phases to avoid dependency issues

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${1}" | tee -a "/tmp/simple-import-$(date +%Y%m%d-%H%M%S).log"
}

log_success() {
    log "${GREEN}✅ ${1}${NC}"
}

log_info() {
    log "${BLUE}ℹ️  ${1}${NC}"
}

log_error() {
    log "${RED}❌ ${1}${NC}"
}

# Navigate to project root
cd /home/daclab-ai/dev/AWS-DevOps/unified-terraform

log_info "🚀 Starting Simple Import Process"
log_info "Phase 1: Check current unified terraform configuration without importing"

# Initialize terraform
log_info "Initializing terraform..."
terraform init

# Create/select dev workspace
terraform workspace new dev 2>/dev/null || terraform workspace select dev

# First, let's see what the unified configuration expects
log_info "Planning unified configuration to see what resources it expects..."
log_info "Using import-friendly configuration..."

if terraform plan -var-file=environments/dev/import.tfvars -out=import-plan.tfplan; then
    log_success "Terraform plan completed - unified system is ready to accept imports"
    
    # Show the plan output
    log_info "Here's what the unified system wants to create:"
    terraform show import-plan.tfplan | head -50
    
    log_info ""
    log_info "🎯 NEXT STEPS RECOMMENDATION:"
    log_info ""
    log_info "The unified system is ready, but importing may be complex due to configuration differences."
    log_info "I recommend one of these approaches:"
    log_info ""
    log_info "OPTION A (Recommended): Deploy unified system to staging first"
    log_info "  1. terraform workspace new staging"
    log_info "  2. terraform apply -var-file=environments/staging/staging.tfvars"
    log_info "  3. Test everything works in staging"
    log_info "  4. Then import to dev workspace"
    log_info ""
    log_info "OPTION B: Continue with current state in old system"
    log_info "  1. Keep using /home/daclab-ai/dev/AWS-DevOps/infrastructure/terraform/core/"
    log_info "  2. Migrate when more convenient"
    log_info ""
    log_info "OPTION C: Fresh deployment in new region"
    log_info "  1. Deploy unified system in us-west-2"
    log_info "  2. Test thoroughly"
    log_info "  3. Migrate applications"
    log_info ""
    
else
    log_error "Terraform plan failed - there may be configuration issues"
    log_info "Check the errors above and fix configuration before proceeding"
fi

log_info "Simple import analysis completed"
