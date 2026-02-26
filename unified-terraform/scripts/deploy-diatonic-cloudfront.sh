#!/usr/bin/env bash
# Deploy Diatonic CloudFront SPA Distribution
# This script creates a properly configured CloudFront distribution for diatonic.ai
# that fixes the SPA routing issue.

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" >&2
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

# Check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform >/dev/null 2>&1; then
        error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    # Check if AWS CLI is installed and configured
    if ! command -v aws >/dev/null 2>&1; then
        error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        error "AWS credentials are not configured properly"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [[ ! -f "$PROJECT_DIR/main.tf" ]]; then
        error "main.tf not found in $PROJECT_DIR"
        exit 1
    fi
    
    log "✅ Prerequisites check passed"
}

# Get SSL certificate ARN for diatonic.ai
get_ssl_certificate() {
    log "🔍 Looking for SSL certificate for diatonic.ai in us-east-1..."
    
    # Check for existing certificate
    local cert_arn=$(aws acm list-certificates \
        --region us-east-1 \
        --certificate-statuses ISSUED \
        --query "CertificateSummaryList[?DomainName=='diatonic.ai' || contains(SubjectAlternativeNameSummary, 'diatonic.ai')].CertificateArn" \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$cert_arn" && "$cert_arn" != "None" ]]; then
        log "✅ Found SSL certificate: $cert_arn"
        echo "$cert_arn"
    else
        warn "❌ No SSL certificate found for diatonic.ai in us-east-1"
        warn "You'll need to either:"
        warn "  1. Create an ACM certificate for diatonic.ai in us-east-1 region"
        warn "  2. Or deploy without custom SSL (will use CloudFront default certificate)"
        echo ""
    fi
}

# Deploy CloudFront distribution
deploy_cloudfront() {
    local workspace="${1:-dev}"
    local ssl_cert_arn="${2:-}"
    
    cd "$PROJECT_DIR"
    
    log "🚀 Starting CloudFront SPA distribution deployment..."
    log "   Workspace: $workspace"
    log "   SSL Certificate: ${ssl_cert_arn:-"Default CloudFront certificate"}"
    
    # Switch to appropriate workspace
    log "🔄 Switching to workspace: $workspace"
    terraform workspace select "$workspace" || terraform workspace new "$workspace"
    
    # Initialize Terraform
    log "🔄 Initializing Terraform..."
    terraform init -upgrade
    
    # Create terraform.tfvars file with SSL certificate if provided
    if [[ -n "$ssl_cert_arn" ]]; then
        cat > terraform.tfvars.temp << EOF
# Temporary variables for diatonic.ai CloudFront deployment
diatonic_ssl_certificate_arn = "$ssl_cert_arn"
enable_cloudflare = true
EOF
        log "📝 Created temporary terraform.tfvars with SSL certificate"
    fi
    
    # Plan the deployment
    log "📋 Planning Terraform deployment..."
    if [[ -f "terraform.tfvars.temp" ]]; then
        terraform plan -var-file="terraform.tfvars.temp" -out="tfplan"
    else
        terraform plan -out="tfplan"
    fi
    
    # Ask for confirmation
    echo ""
    echo -e "${BLUE}📋 Terraform Plan Summary:${NC}"
    echo -e "${BLUE}   • Creates CloudFront distribution for diatonic.ai${NC}"
    echo -e "${BLUE}   • Configures proper SPA routing (fixes JS/CSS serving issue)${NC}"
    echo -e "${BLUE}   • Sets up asset-specific cache behaviors${NC}"
    echo -e "${BLUE}   • Configures S3 origin access identity${NC}"
    echo ""
    
    read -p "Do you want to proceed with the deployment? [y/N] " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "🚀 Applying Terraform configuration..."
        terraform apply "tfplan"
        
        # Clean up temporary files
        if [[ -f "terraform.tfvars.temp" ]]; then
            rm -f "terraform.tfvars.temp"
        fi
        rm -f "tfplan"
        
        # Get outputs
        log "📊 Getting deployment outputs..."
        local distribution_id=$(terraform output -raw diatonic_cloudfront_distribution_id 2>/dev/null || echo "")
        local distribution_domain=$(terraform output -raw diatonic_cloudfront_domain_name 2>/dev/null || echo "")
        local function_arn=$(terraform output -raw diatonic_spa_function_arn 2>/dev/null || echo "")
        
        log "✅ CloudFront SPA distribution deployed successfully!"
        echo ""
        echo -e "${GREEN}📊 Deployment Results:${NC}"
        echo -e "${GREEN}   Distribution ID: ${distribution_id}${NC}"
        echo -e "${GREEN}   Distribution Domain: ${distribution_domain}${NC}"
        echo -e "${GREEN}   SPA Function ARN: ${function_arn}${NC}"
        echo ""
        
        # Update Cloudflare DNS (if applicable)
        if [[ -n "$distribution_domain" ]]; then
            log "🔄 Next Steps:"
            echo -e "${YELLOW}   1. Update Cloudflare DNS to point to new distribution:${NC}"
            echo -e "${YELLOW}      • CNAME: www.diatonic.ai -> ${distribution_domain}${NC}"
            echo -e "${YELLOW}      • A: diatonic.ai -> CloudFront IPs${NC}"
            echo ""
            echo -e "${YELLOW}   2. Test the fix:${NC}"
            echo -e "${YELLOW}      curl -sSL https://${distribution_domain}/assets/index-DzYP2ee5.js | head -3${NC}"
            echo -e "${YELLOW}      (Should show JavaScript, not HTML)${NC}"
            echo ""
            echo -e "${YELLOW}   3. Create CloudFront invalidation to clear cache:${NC}"
            echo -e "${YELLOW}      aws cloudfront create-invalidation --distribution-id ${distribution_id} --paths '/*'${NC}"
        fi
        
    else
        log "❌ Deployment cancelled by user"
        rm -f "tfplan"
        if [[ -f "terraform.tfvars.temp" ]]; then
            rm -f "terraform.tfvars.temp"
        fi
        exit 1
    fi
}

# Create invalidation for existing distribution (if it exists)
create_invalidation() {
    local distribution_id="$1"
    
    log "🔄 Creating CloudFront invalidation for distribution: $distribution_id"
    
    local invalidation_id=$(aws cloudfront create-invalidation \
        --distribution-id "$distribution_id" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text)
    
    if [[ -n "$invalidation_id" ]]; then
        log "✅ Invalidation created: $invalidation_id"
        log "⏳ Invalidation may take 5-15 minutes to complete"
    else
        warn "❌ Failed to create invalidation"
    fi
}

# Test the fix
test_spa_fix() {
    local domain="${1:-www.diatonic.ai}"
    
    log "🧪 Testing SPA fix for domain: $domain"
    
    # Test JavaScript asset
    log "   Testing JavaScript asset..."
    local js_response=$(curl -sSL "https://$domain/assets/index-DzYP2ee5.js" | head -3)
    
    if echo "$js_response" | grep -q "<!DOCTYPE html>"; then
        error "❌ JavaScript asset still returns HTML - SPA routing issue not fixed"
        echo "Response:"
        echo "$js_response"
        return 1
    else
        log "✅ JavaScript asset returns proper JavaScript content"
    fi
    
    # Test CSS asset
    log "   Testing CSS asset..."
    local css_response=$(curl -sSL "https://$domain/assets/index-BxurtWjp.css" | head -3)
    
    if echo "$css_response" | grep -q "<!DOCTYPE html>"; then
        warn "⚠️  CSS asset returns HTML - may need additional testing"
    else
        log "✅ CSS asset returns proper CSS content"
    fi
    
    # Test HTML page
    log "   Testing HTML page..."
    local html_response=$(curl -sSL "https://$domain/" | head -10)
    
    if echo "$html_response" | grep -q "<!DOCTYPE html>"; then
        log "✅ HTML page returns proper HTML content"
    else
        warn "⚠️  HTML page response unexpected"
    fi
    
    log "✅ SPA fix test completed"
}

# Main function
main() {
    local workspace="${1:-dev}"
    local action="${2:-deploy}"
    
    log "🎯 Starting Diatonic CloudFront SPA deployment script"
    log "   Workspace: $workspace"
    log "   Action: $action"
    
    check_prerequisites
    
    case "$action" in
        "deploy")
            local ssl_cert_arn=$(get_ssl_certificate)
            deploy_cloudfront "$workspace" "$ssl_cert_arn"
            ;;
        "test")
            test_spa_fix
            ;;
        "invalidate")
            local dist_id="${3:-}"
            if [[ -z "$dist_id" ]]; then
                cd "$PROJECT_DIR"
                terraform workspace select "$workspace"
                dist_id=$(terraform output -raw diatonic_cloudfront_distribution_id 2>/dev/null || echo "")
            fi
            if [[ -n "$dist_id" ]]; then
                create_invalidation "$dist_id"
            else
                error "Distribution ID not found. Please provide it as third argument."
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [workspace] [deploy|test|invalidate] [distribution-id]"
            echo ""
            echo "Examples:"
            echo "  $0 dev deploy                    # Deploy to dev workspace"
            echo "  $0 prod deploy                   # Deploy to prod workspace"  
            echo "  $0 dev test                      # Test SPA fix"
            echo "  $0 dev invalidate E123456789     # Create invalidation"
            exit 1
            ;;
    esac
    
    log "🎉 Script completed successfully!"
}

# Run main function with all arguments
main "$@"
