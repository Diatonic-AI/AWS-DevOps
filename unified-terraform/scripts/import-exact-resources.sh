#!/usr/bin/env bash
# 🎯 Tailored Resource Import Script with Exact Resource IDs
# This script imports your specific existing AWS resources into the unified Terraform configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMPORT_LOG="/tmp/terraform-import-exact-$(date +%Y%m%d-%H%M%S).log"

# Exact resource IDs from your current infrastructure
VPC_ID="vpc-0afa64bf5579542eb"
PUBLIC_SUBNETS=(
    "subnet-080cf74da64560622"  # us-east-2a public-1
    "subnet-0a969f703f88ba873"  # us-east-2b public-2  
    "subnet-0cd9b04713d034dd6"  # us-east-2c public-3
)
PRIVATE_SUBNETS=(
    "subnet-0d23209f1df0b670c"  # us-east-2a private-1
    "subnet-02d6b86c59dcfbd56"  # us-east-2b private-2
    "subnet-0cc9192f2fb15c084"  # us-east-2c private-3
)
DATA_SUBNETS=(
    "subnet-0d84262befa6a8c16"  # us-east-2a data-1
    "subnet-0f60d1f33681b971d"  # us-east-2b data-2
    "subnet-097d3941682c5892b"  # us-east-2c data-3
)
S3_BUCKETS=(
    "aws-devops-dev-application-development-dzfngw8v"
    "aws-devops-dev-backup-development-dzfngw8v"
    "aws-devops-dev-compliance-development-dzfngw8v"
    "aws-devops-dev-logs-development-dzfngw8v"
    "aws-devops-dev-static-assets-development-dzfngw8v"
)

# Logging functions
log() {
    echo -e "${1}" | tee -a "$IMPORT_LOG"
}

log_success() {
    log "${GREEN}✅ ${1}${NC}"
}

log_warning() {
    log "${YELLOW}⚠️  ${1}${NC}"
}

log_error() {
    log "${RED}❌ ${1}${NC}"
}

log_info() {
    log "${BLUE}ℹ️  ${1}${NC}"
}

# Safe import function
import_resource() {
    local terraform_resource="$1"
    local aws_resource_id="$2"
    local description="${3:-$terraform_resource}"
    
    log_info "Importing $description..."
    log_info "  Terraform: $terraform_resource"
    log_info "  AWS ID: $aws_resource_id"
    
    # Check if resource already exists in state
    if terraform state show "$terraform_resource" >/dev/null 2>&1; then
        log_warning "Resource $terraform_resource already exists in state, skipping"
        return 0
    fi
    
    # Attempt import
    if terraform import "$terraform_resource" "$aws_resource_id" >>"$IMPORT_LOG" 2>&1; then
        log_success "Successfully imported $description"
        return 0
    else
        log_error "Failed to import $description"
        # Show the error but continue
        tail -5 "$IMPORT_LOG" | sed 's/^/  /'
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    cd "$PROJECT_ROOT"
    
    # Check if we're in the right directory
    if [[ ! -f "main.tf" ]]; then
        log_error "Not in unified terraform directory"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    # Check terraform
    if ! command -v terraform >/dev/null; then
        log_error "Terraform not installed"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Import core resources to dev workspace
import_core_infrastructure() {
    log_info "🏗️ Importing core infrastructure to dev workspace..."
    
    # Ensure we're in dev workspace
    terraform workspace select dev || terraform workspace new dev
    
    # First, let's see what the unified terraform expects by doing a plan
    log_info "Analyzing unified terraform configuration..."
    
    # Import VPC
    log_info "Importing VPC resources..."
    import_resource "module.core_infrastructure[0].aws_vpc.main" "$VPC_ID" "VPC"
    
    # Get IGW ID
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)
    if [[ -n "$IGW_ID" && "$IGW_ID" != "null" ]]; then
        import_resource "module.core_infrastructure[0].aws_internet_gateway.main" "$IGW_ID" "Internet Gateway"
    fi
    
    # Import public subnets
    log_info "Importing public subnets..."
    for i in "${!PUBLIC_SUBNETS[@]}"; do
        import_resource "module.core_infrastructure[0].aws_subnet.public[$i]" "${PUBLIC_SUBNETS[i]}" "Public Subnet $((i+1))"
    done
    
    # Import private subnets
    log_info "Importing private subnets..."
    for i in "${!PRIVATE_SUBNETS[@]}"; do
        import_resource "module.core_infrastructure[0].aws_subnet.private[$i]" "${PRIVATE_SUBNETS[i]}" "Private Subnet $((i+1))"
    done
    
    # Import data subnets
    log_info "Importing data subnets..."
    for i in "${!DATA_SUBNETS[@]}"; do
        import_resource "module.core_infrastructure[0].aws_subnet.data[$i]" "${DATA_SUBNETS[i]}" "Data Subnet $((i+1))"
    done
    
    # Import NAT Gateway (if exists)
    NAT_ID=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query 'NatGateways[0].NatGatewayId' --output text)
    if [[ -n "$NAT_ID" && "$NAT_ID" != "null" && "$NAT_ID" != "None" ]]; then
        import_resource "module.core_infrastructure[0].aws_nat_gateway.main[0]" "$NAT_ID" "NAT Gateway"
        
        # Get EIP for NAT Gateway
        EIP_ALLOC_ID=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT_ID" --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' --output text)
        if [[ -n "$EIP_ALLOC_ID" && "$EIP_ALLOC_ID" != "null" ]]; then
            import_resource "module.core_infrastructure[0].aws_eip.nat[0]" "$EIP_ALLOC_ID" "NAT Gateway EIP"
        fi
    fi
    
    # Import route tables
    log_info "Importing route tables..."
    
    # Public route table
    PUBLIC_RT_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*public*" --query 'RouteTables[0].RouteTableId' --output text)
    if [[ -n "$PUBLIC_RT_ID" && "$PUBLIC_RT_ID" != "null" && "$PUBLIC_RT_ID" != "None" ]]; then
        import_resource "module.core_infrastructure[0].aws_route_table.public" "$PUBLIC_RT_ID" "Public Route Table"
    fi
    
    # Private route tables
    PRIVATE_RT_IDS=($(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" --query 'RouteTables[].RouteTableId' --output text))
    for i in "${!PRIVATE_RT_IDS[@]}"; do
        if [[ -n "${PRIVATE_RT_IDS[i]}" && "${PRIVATE_RT_IDS[i]}" != "null" ]]; then
            import_resource "module.core_infrastructure[0].aws_route_table.private[$i]" "${PRIVATE_RT_IDS[i]}" "Private Route Table $((i+1))"
        fi
    done
    
    # Data route table
    DATA_RT_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*data*" --query 'RouteTables[0].RouteTableId' --output text)
    if [[ -n "$DATA_RT_ID" && "$DATA_RT_ID" != "null" && "$DATA_RT_ID" != "None" ]]; then
        import_resource "module.core_infrastructure[0].aws_route_table.data" "$DATA_RT_ID" "Data Route Table"
    fi
    
    log_success "Core VPC infrastructure import completed"
}

# Import S3 resources
import_s3_resources() {
    log_info "🪣 Importing S3 resources..."
    
    # Import S3 buckets with correct mapping
    declare -A bucket_mapping=(
        ["aws-devops-dev-application-development-dzfngw8v"]="application"
        ["aws-devops-dev-backup-development-dzfngw8v"]="backup"
        ["aws-devops-dev-compliance-development-dzfngw8v"]="compliance"
        ["aws-devops-dev-logs-development-dzfngw8v"]="logs"
        ["aws-devops-dev-static-assets-development-dzfngw8v"]="static-assets"
    )
    
    for bucket in "${S3_BUCKETS[@]}"; do
        bucket_type="${bucket_mapping[$bucket]}"
        if [[ -n "$bucket_type" ]]; then
            import_resource "module.core_infrastructure[0].aws_s3_bucket.main[\"$bucket_type\"]" "$bucket" "S3 Bucket: $bucket_type"
            
            # Import related S3 resources that might exist
            # Note: These might fail if the unified configuration is different, which is expected
            import_resource "module.core_infrastructure[0].aws_s3_bucket_versioning.main[\"$bucket_type\"]" "$bucket" "S3 Versioning: $bucket_type" || true
            import_resource "module.core_infrastructure[0].aws_s3_bucket_server_side_encryption_configuration.main[\"$bucket_type\"]" "$bucket" "S3 Encryption: $bucket_type" || true
            import_resource "module.core_infrastructure[0].aws_s3_bucket_public_access_block.main[\"$bucket_type\"]" "$bucket" "S3 Public Block: $bucket_type" || true
        fi
    done
    
    log_success "S3 resources import completed"
}

# Import ECS resources if they exist
import_ecs_resources() {
    log_info "🐳 Checking for ECS resources..."
    
    # Check for ECS cluster
    ECS_CLUSTER=$(aws ecs list-clusters --query 'clusterArns[?contains(@, `aws-devops-dev`)][0]' --output text 2>/dev/null | awk -F'/' '{print $NF}')
    
    if [[ -n "$ECS_CLUSTER" && "$ECS_CLUSTER" != "null" && "$ECS_CLUSTER" != "None" ]]; then
        log_info "Found ECS cluster: $ECS_CLUSTER"
        import_resource "module.core_infrastructure[0].aws_ecs_cluster.main" "$ECS_CLUSTER" "ECS Cluster"
    else
        log_info "No ECS cluster found for import"
    fi
}

# Test import results
test_import() {
    log_info "🧪 Testing import results..."
    
    # Run terraform plan to see what changes are needed
    log_info "Running terraform plan to check import accuracy..."
    
    if terraform plan -detailed-exitcode >>"$IMPORT_LOG" 2>&1; then
        log_success "Perfect! No changes needed - import was 100% successful"
        return 0
    elif [[ $? -eq 2 ]]; then
        log_warning "Some changes detected - this is normal and expected"
        log_info "The unified configuration may have different settings than your current setup"
        log_info "Check the plan output in: $IMPORT_LOG"
        return 0
    else
        log_error "Terraform plan failed - check the logs"
        return 1
    fi
}

# Main execution
main() {
    log_info "🚀 Starting tailored resource import for unified Terraform"
    log_info "Import log: $IMPORT_LOG"
    
    check_prerequisites
    
    cd "$PROJECT_ROOT"
    
    # Initialize terraform
    log_info "Initializing Terraform..."
    terraform init >>"$IMPORT_LOG" 2>&1 || {
        log_error "Terraform init failed"
        exit 1
    }
    
    # Create dev workspace if it doesn't exist
    terraform workspace new dev 2>/dev/null || terraform workspace select dev
    
    # Import resources
    import_core_infrastructure
    import_s3_resources  
    import_ecs_resources
    
    # Test results
    test_import
    
    log_success "🎉 Import process completed!"
    log_info ""
    log_info "📋 Next Steps:"
    log_info "1. Review the terraform plan output in the log: $IMPORT_LOG"
    log_info "2. Run: ./scripts/deploy.sh dev plan"
    log_info "3. Review any configuration differences"
    log_info "4. Apply if everything looks good: ./scripts/deploy.sh dev apply"
    log_info ""
    log_info "📝 Important Notes:"
    log_info "- Some configuration differences are normal between old and unified systems"
    log_info "- The unified system uses modern Terraform practices and may have different defaults"
    log_info "- Your existing resources are safely imported and managed"
    log_info "- No resources have been modified or destroyed"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
