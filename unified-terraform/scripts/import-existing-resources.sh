#!/usr/bin/env bash
# 🚀 Comprehensive Resource Import Script for Unified Terraform
# This script safely imports existing AWS resources into the unified Terraform configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="/home/daclab-ai/dev/AWS-DevOps/backups/pre-migration-20250908-071622"
IMPORT_LOG="/tmp/terraform-import-$(date +%Y%m%d-%H%M%S).log"

# Initialize logging
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "$PROJECT_ROOT/main.tf" ]]; then
        log_error "Not in unified terraform directory. Please run from /home/daclab-ai/dev/AWS-DevOps/unified-terraform"
        exit 1
    fi
    
    # Check if backup exists
    if [[ ! -f "$BACKUP_DIR/core_resources.txt" ]]; then
        log_error "Backup not found at $BACKUP_DIR. Please run backup first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check terraform
    if ! command -v terraform >/dev/null; then
        log_error "Terraform not installed"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to safely import a resource
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
    
    # Check if AWS resource exists
    if [[ -z "$aws_resource_id" || "$aws_resource_id" == "null" ]]; then
        log_warning "AWS resource ID is empty or null, skipping $description"
        return 0
    fi
    
    # Attempt import
    if terraform import "$terraform_resource" "$aws_resource_id" >>"$IMPORT_LOG" 2>&1; then
        log_success "Successfully imported $description"
        return 0
    else
        log_error "Failed to import $description (this may be expected for some resources)"
        return 1
    fi
}

# Function to get AWS resource IDs
get_vpc_id() {
    aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=*aws-devops-dev*" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null || echo ""
}

get_igw_id() {
    local vpc_id="$1"
    aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$vpc_id" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null || echo ""
}

get_nat_gateway_id() {
    local vpc_id="$1"
    aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=$vpc_id" "Name=state,Values=available" \
        --query 'NatGateways[0].NatGatewayId' \
        --output text 2>/dev/null || echo ""
}

get_subnet_ids() {
    local vpc_id="$1"
    local subnet_type="$2"  # public, private, data
    
    aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=*$subnet_type*" \
        --query 'Subnets[].SubnetId' \
        --output text 2>/dev/null || echo ""
}

get_s3_bucket_names() {
    aws s3api list-buckets \
        --query 'Buckets[?contains(Name, `aws-devops-dev`)].Name' \
        --output text 2>/dev/null || echo ""
}

get_ecs_cluster_name() {
    aws ecs list-clusters \
        --query 'clusterArns[?contains(@, `aws-devops-dev`)][0]' \
        --output text 2>/dev/null | awk -F'/' '{print $NF}' || echo ""
}

# Main import function
import_core_infrastructure() {
    log_info "Starting core infrastructure import to dev workspace..."
    
    # Ensure we're in dev workspace
    terraform workspace select dev || terraform workspace new dev
    
    # Get core AWS resource IDs
    log_info "Discovering AWS resource IDs..."
    VPC_ID=$(get_vpc_id)
    log_info "VPC ID: ${VPC_ID:-'Not found'}"
    
    if [[ -n "$VPC_ID" && "$VPC_ID" != "null" ]]; then
        IGW_ID=$(get_igw_id "$VPC_ID")
        NAT_ID=$(get_nat_gateway_id "$VPC_ID")
        PUBLIC_SUBNETS=($(get_subnet_ids "$VPC_ID" "public"))
        PRIVATE_SUBNETS=($(get_subnet_ids "$VPC_ID" "private"))
        DATA_SUBNETS=($(get_subnet_ids "$VPC_ID" "data"))
        
        log_info "IGW ID: ${IGW_ID:-'Not found'}"
        log_info "NAT Gateway ID: ${NAT_ID:-'Not found'}"
        log_info "Public Subnets: ${PUBLIC_SUBNETS[*]:-'None found'}"
        log_info "Private Subnets: ${PRIVATE_SUBNETS[*]:-'None found'}"
        log_info "Data Subnets: ${DATA_SUBNETS[*]:-'None found'}"
    fi
    
    # Import VPC resources
    if [[ -n "$VPC_ID" && "$VPC_ID" != "null" ]]; then
        import_resource "module.core_infrastructure[0].aws_vpc.main" "$VPC_ID" "VPC"
        
        if [[ -n "$IGW_ID" && "$IGW_ID" != "null" ]]; then
            import_resource "module.core_infrastructure[0].aws_internet_gateway.main" "$IGW_ID" "Internet Gateway"
        fi
        
        # Import public subnets
        for i in "${!PUBLIC_SUBNETS[@]}"; do
            if [[ -n "${PUBLIC_SUBNETS[i]}" && "${PUBLIC_SUBNETS[i]}" != "null" ]]; then
                import_resource "module.core_infrastructure[0].aws_subnet.public[$i]" "${PUBLIC_SUBNETS[i]}" "Public Subnet $i"
            fi
        done
        
        # Import private subnets
        for i in "${!PRIVATE_SUBNETS[@]}"; do
            if [[ -n "${PRIVATE_SUBNETS[i]}" && "${PRIVATE_SUBNETS[i]}" != "null" ]]; then
                import_resource "module.core_infrastructure[0].aws_subnet.private[$i]" "${PRIVATE_SUBNETS[i]}" "Private Subnet $i"
            fi
        done
        
        # Import data subnets
        for i in "${!DATA_SUBNETS[@]}"; do
            if [[ -n "${DATA_SUBNETS[i]}" && "${DATA_SUBNETS[i]}" != "null" ]]; then
                import_resource "module.core_infrastructure[0].aws_subnet.data[$i]" "${DATA_SUBNETS[i]}" "Data Subnet $i"
            fi
        done
        
        # Import NAT Gateway (if exists)
        if [[ -n "$NAT_ID" && "$NAT_ID" != "null" ]]; then
            import_resource "module.core_infrastructure[0].aws_nat_gateway.main[0]" "$NAT_ID" "NAT Gateway"
        fi
    fi
    
    # Import S3 buckets
    log_info "Importing S3 buckets..."
    S3_BUCKETS=($(get_s3_bucket_names))
    for bucket in "${S3_BUCKETS[@]}"; do
        if [[ -n "$bucket" && "$bucket" != "null" ]]; then
            # Try to import based on common patterns
            if [[ "$bucket" == *"static"* ]]; then
                import_resource "module.core_infrastructure[0].aws_s3_bucket.main[\"static-assets\"]" "$bucket" "S3 Static Assets Bucket"
            elif [[ "$bucket" == *"log"* ]]; then
                import_resource "module.core_infrastructure[0].aws_s3_bucket.main[\"logs\"]" "$bucket" "S3 Logs Bucket"
            elif [[ "$bucket" == *"backup"* ]]; then
                import_resource "module.core_infrastructure[0].aws_s3_bucket.main[\"backup\"]" "$bucket" "S3 Backup Bucket"
            elif [[ "$bucket" == *"compliance"* ]]; then
                import_resource "module.core_infrastructure[0].aws_s3_bucket.main[\"compliance\"]" "$bucket" "S3 Compliance Bucket"
            else
                import_resource "module.core_infrastructure[0].aws_s3_bucket.main[\"application\"]" "$bucket" "S3 Application Bucket"
            fi
        fi
    done
    
    # Import ECS resources
    log_info "Importing ECS resources..."
    ECS_CLUSTER=$(get_ecs_cluster_name)
    if [[ -n "$ECS_CLUSTER" && "$ECS_CLUSTER" != "null" ]]; then
        import_resource "module.core_infrastructure[0].aws_ecs_cluster.main" "$ECS_CLUSTER" "ECS Cluster"
    fi
    
    log_success "Core infrastructure import completed"
}

# Function to import AI Nexus resources
import_ai_nexus_resources() {
    log_info "Starting AI Nexus resources import to ai-nexus workspace..."
    
    # Create and switch to ai-nexus workspace
    terraform workspace select ai-nexus 2>/dev/null || terraform workspace new ai-nexus
    
    # Get Cognito User Pool
    USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 20 \
        --query 'UserPools[?contains(Name, `ai-nexus`) || contains(Name, `ainexus`)].Id' \
        --output text 2>/dev/null | head -1 || echo "")
        
    if [[ -n "$USER_POOL_ID" && "$USER_POOL_ID" != "null" ]]; then
        import_resource "module.ai_nexus_workbench[0].aws_cognito_user_pool.main" "$USER_POOL_ID" "Cognito User Pool"
    fi
    
    # Import DynamoDB tables
    DYNAMO_TABLES=$(aws dynamodb list-tables \
        --query 'TableNames[?contains(@,`ai-nexus`) || contains(@,`ainexus`)]' \
        --output text 2>/dev/null || echo "")
        
    for table in $DYNAMO_TABLES; do
        if [[ -n "$table" && "$table" != "null" ]]; then
            import_resource "module.ai_nexus_workbench[0].aws_dynamodb_table.main[\"$table\"]" "$table" "DynamoDB Table: $table"
        fi
    done
    
    # Import Lambda functions
    LAMBDA_FUNCTIONS=$(aws lambda list-functions \
        --query 'Functions[?contains(FunctionName,`ai-nexus`) || contains(FunctionName,`ainexus`)].FunctionName' \
        --output text 2>/dev/null || echo "")
        
    for func in $LAMBDA_FUNCTIONS; do
        if [[ -n "$func" && "$func" != "null" ]]; then
            import_resource "module.ai_nexus_workbench[0].aws_lambda_function.main[\"$func\"]" "$func" "Lambda Function: $func"
        fi
    done
    
    log_success "AI Nexus resources import completed"
}

# Validation function
validate_import() {
    log_info "Validating imported resources..."
    
    local errors=0
    
    # Check each workspace
    for workspace in dev ai-nexus; do
        if terraform workspace list | grep -q "$workspace"; then
            log_info "Validating workspace: $workspace"
            terraform workspace select "$workspace"
            
            if terraform plan -detailed-exitcode >>"$IMPORT_LOG" 2>&1; then
                log_success "Workspace $workspace: No changes needed (perfect import)"
            elif [[ $? -eq 2 ]]; then
                log_warning "Workspace $workspace: Some changes detected (may need configuration adjustments)"
            else
                log_error "Workspace $workspace: Validation failed"
                ((errors++))
            fi
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        log_success "Import validation completed successfully"
        return 0
    else
        log_error "Import validation found issues in $errors workspace(s)"
        return 1
    fi
}

# Create state mapping file for reference
create_state_mapping() {
    log_info "Creating state mapping documentation..."
    
    cat > "$PROJECT_ROOT/STATE_MAPPING.md" << 'EOF'
# State Mapping Documentation

This document maps old Terraform state resources to new unified state resources.

## Dev Workspace (Core Infrastructure)
Maps resources from: `/home/daclab-ai/dev/AWS-DevOps/infrastructure/terraform/core/`

### VPC Resources
- `module.vpc.aws_vpc.main` → `module.core_infrastructure[0].aws_vpc.main`
- `module.vpc.aws_internet_gateway.main` → `module.core_infrastructure[0].aws_internet_gateway.main`
- `module.vpc.aws_subnet.public[*]` → `module.core_infrastructure[0].aws_subnet.public[*]`
- `module.vpc.aws_subnet.private[*]` → `module.core_infrastructure[0].aws_subnet.private[*]`
- `module.vpc.aws_subnet.data[*]` → `module.core_infrastructure[0].aws_subnet.data[*]`

### S3 Resources
- `module.s3.aws_s3_bucket.main[*]` → `module.core_infrastructure[0].aws_s3_bucket.main[*]`

### ECS Resources
- `module.web_application.aws_ecs_cluster.main` → `module.core_infrastructure[0].aws_ecs_cluster.main`

## AI-Nexus Workspace
Maps resources from: `/home/daclab-ai/dev/AWS-DevOps/apps/ai-nexus-workbench/infrastructure/`

### Cognito Resources
- User Pools → `module.ai_nexus_workbench[0].aws_cognito_user_pool.main`

### DynamoDB Resources
- Tables → `module.ai_nexus_workbench[0].aws_dynamodb_table.main[*]`

### Lambda Resources
- Functions → `module.ai_nexus_workbench[0].aws_lambda_function.main[*]`

## Import Log
Check the import log for detailed import results: `$IMPORT_LOG`
EOF

    log_success "State mapping documentation created: $PROJECT_ROOT/STATE_MAPPING.md"
}

# Main execution
main() {
    log_info "🚀 Starting comprehensive Terraform resource import"
    log_info "Import log: $IMPORT_LOG"
    
    check_prerequisites
    
    cd "$PROJECT_ROOT"
    
    # Initialize terraform
    log_info "Initializing Terraform..."
    terraform init >>"$IMPORT_LOG" 2>&1 || {
        log_error "Terraform init failed"
        exit 1
    }
    
    # Import core infrastructure
    import_core_infrastructure
    
    # Import AI Nexus resources if they exist
    if [[ -d "/home/daclab-ai/dev/AWS-DevOps/apps/ai-nexus-workbench" ]]; then
        import_ai_nexus_resources
    else
        log_info "No AI Nexus workbench found, skipping AI Nexus import"
    fi
    
    # Create documentation
    create_state_mapping
    
    # Validate import
    if validate_import; then
        log_success "🎉 Import process completed successfully!"
        log_info "Next steps:"
        log_info "1. Review the state mapping: cat $PROJECT_ROOT/STATE_MAPPING.md"
        log_info "2. Test deployments: ./scripts/deploy.sh dev plan"
        log_info "3. Check the import log: cat $IMPORT_LOG"
    else
        log_warning "Import completed with some issues. Check the import log: $IMPORT_LOG"
        log_info "You may need to adjust some resource configurations manually."
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
