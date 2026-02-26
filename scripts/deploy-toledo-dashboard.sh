#!/bin/bash

# Toledo Consulting Dashboard Deployment Script
# Deploys complete partner dashboard infrastructure

set -euo pipefail

# Configuration
PARTNER_NAME="toledo-consulting"
ENVIRONMENT="prod"
AWS_REGION="us-east-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI not found. Please install AWS CLI."
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraform not found. Please install Terraform."
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid."
    fi
    
    # Get the script directory and navigate to project root
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
    
    # Check if we can find the required terraform file
    if [[ ! -f "${PROJECT_ROOT}/infrastructure/terraform/environments/prod/toledo-consulting-dashboard.tf" ]]; then
        error "Cannot find toledo-consulting-dashboard.tf in expected location: ${PROJECT_ROOT}/infrastructure/terraform/environments/prod/"
    fi
    
    log "Prerequisites check passed ✓"
}

# Initialize Terraform
init_terraform() {
    log "Initializing Terraform..."
    
    # Get the script directory and navigate to project root
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
    cd "${PROJECT_ROOT}/infrastructure/terraform/environments/prod"
    
    # Initialize with remote backend if configured
    terraform init
    
    log "Terraform initialized ✓"
}

# Validate Terraform configuration
validate_terraform() {
    log "Validating Terraform configuration..."
    
    terraform validate
    terraform fmt -check=true -recursive
    
    log "Terraform configuration valid ✓"
}

# Plan Terraform deployment
plan_terraform() {
    log "Planning Terraform deployment..."
    
    terraform plan -out="toledo-dashboard-${ENVIRONMENT}.tfplan"
    
    log "Terraform plan created ✓"
}

# Apply Terraform deployment
apply_terraform() {
    log "Applying Terraform deployment..."
    
    terraform apply "toledo-dashboard-${ENVIRONMENT}.tfplan"
    
    log "Terraform deployment applied ✓"
}

# Get outputs and update frontend
update_frontend() {
    log "Updating frontend configuration..."
    
    # Get API Gateway URL
    API_URL=$(terraform output -raw toledo_api_url)
    S3_BUCKET=$(terraform output -raw toledo_s3_bucket_name)
    
    # Navigate to frontend directory from project root
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
    cd "${PROJECT_ROOT}/dashboard-frontend"
    
    # Update API URL in the frontend
    sed -i "s|YOUR_API_GATEWAY_URL_HERE|${API_URL}|g" index.html
    
    log "Frontend updated with API URL: ${API_URL}"
    
    # Upload to S3
    log "Uploading frontend to S3..."
    aws s3 cp index.html "s3://${S3_BUCKET}/" --region="${AWS_REGION}"
    
    log "Frontend uploaded to S3 ✓"
}

# Test deployment
test_deployment() {
    log "Testing deployment..."
    
    # We should already be in the prod directory from previous steps
    # But let's make sure we're in the right place
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
    cd "${PROJECT_ROOT}/infrastructure/terraform/environments/prod"
    
    # Get URLs
    DASHBOARD_URL=$(terraform output -raw toledo_dashboard_url)
    API_URL=$(terraform output -raw toledo_api_url)
    
    # Test API health endpoint
    log "Testing API health endpoint..."
    if curl -s "${API_URL}/health" | grep -q "healthy"; then
        log "API health check passed ✓"
    else
        warn "API health check failed - deployment may still be propagating"
    fi
    
    log "Deployment test completed ✓"
    
    # Display access information
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Toledo Consulting Dashboard Deployed${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo -e "Dashboard URL: ${GREEN}${DASHBOARD_URL}${NC}"
    echo -e "API Gateway URL: ${GREEN}${API_URL}${NC}"
    echo -e "CloudWatch Dashboard: ${GREEN}$(terraform output -raw toledo_cloudwatch_dashboard)${NC}"
    echo
    echo -e "Partner Login:"
    echo -e "  Console: ${GREEN}https://313476888312.signin.aws.amazon.com/console${NC}"
    echo -e "  Username: ${GREEN}toledo-consulting-admin${NC}"
    echo -e "  Password: ${GREEN}X*d^9LdlwU&Ahh$e ✅ READY TO USE${NC}"
    echo
    echo -e "${YELLOW}Note: Allow 10-15 minutes for CloudFront distribution to fully propagate${NC}"
    echo
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    # Get the script directory and navigate to project root
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 2>/dev/null || {
        warn "Could not determine script directory, skipping cleanup"
        return 0
    }
    PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )" 2>/dev/null || {
        warn "Could not determine project root, skipping cleanup"
        return 0
    }
    
    if cd "${PROJECT_ROOT}/infrastructure/terraform/environments/prod" 2>/dev/null; then
        rm -f toledo-dashboard-*.tfplan
        log "Cleanup completed ✓"
    else
        warn "Could not navigate to terraform directory, skipping plan file cleanup"
    fi
}

# Main deployment function
main() {
    log "Starting Toledo Consulting Dashboard deployment..."
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    check_prerequisites
    init_terraform
    validate_terraform
    plan_terraform
    
    # Prompt for confirmation
    echo
    echo -e "${YELLOW}Ready to deploy Toledo Consulting Dashboard infrastructure.${NC}"
    echo -e "This will create:"
    echo -e "  - S3 bucket for dashboard assets"
    echo -e "  - DynamoDB table for dashboard data"
    echo -e "  - Lambda function for dashboard API"
    echo -e "  - API Gateway for dashboard endpoints"
    echo -e "  - CloudWatch dashboard for metrics"
    echo -e "  - CloudFront distribution for content delivery"
    echo
    read -p "Continue with deployment? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
    
    apply_terraform
    update_frontend
    test_deployment
    
    log "Toledo Consulting Dashboard deployment completed successfully! 🎉"
}

# Run main function
main "$@"