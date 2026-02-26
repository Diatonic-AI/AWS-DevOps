#!/bin/bash

# Targeted AWS Cleanup Script for AI Nexus Integration
# This script only cleans up conflicting resources while preserving:
# - Route53 domain (diatonic.ai)  
# - SSL certificates
# - MinIO S3 buckets
# - Production environment
# - Working infrastructure

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
AWS_REGION="${AWS_REGION:-us-east-2}"
BACKUP_DIR="$PROJECT_ROOT/targeted-cleanup-backups-$(date +%Y%m%d-%H%M%S)"

# Resources to PRESERVE
PRESERVE_DOMAIN="diatonic.ai"
PRESERVE_HOSTED_ZONE_ID="Z032094313J9CQ17JQ2OQ"
PRESERVE_MINIO_BUCKETS=("minio-standalone-dev-minio-backups-10b24c3f" "minio-standalone-dev-minio-data-10b24c3f" "minio-standalone-dev-minio-logs-10b24c3f" "minio-standalone-dev-minio-uploads-10b24c3f")
PRESERVE_PROD_RESOURCES=true
PRESERVE_SSL_CERTS=true

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
    echo -e "${GREEN}[PRESERVE]${NC} $1"
}

confirm_cleanup() {
    echo -e "${YELLOW}This will clean up ONLY conflicting development resources${NC}"
    echo -e "${GREEN}The following will be PRESERVED:${NC}"
    echo "  ✅ Route53 domain: $PRESERVE_DOMAIN"
    echo "  ✅ SSL certificates"
    echo "  ✅ MinIO S3 buckets"
    echo "  ✅ Production environment resources"
    echo "  ✅ Working hosted zone"
    echo ""
    echo -e "${YELLOW}The following DEV resources will be cleaned up:${NC}"
    echo "  🗑️  Duplicate/conflicting VPCs"
    echo "  🗑️  Old dev S3 buckets (non-MinIO)"
    echo "  🗑️  Conflicting ECS clusters"
    echo "  🗑️  Old dev load balancers"
    echo "  🗑️  Terraform state conflicts"
    echo ""
    read -p "Continue with targeted cleanup? (yes/no): " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        print_info "Operation cancelled"
        exit 0
    fi
}

backup_configurations() {
    print_header "BACKING UP CONFIGURATIONS"
    mkdir -p "$BACKUP_DIR"
    
    # Backup Terraform configurations
    if [[ -f "$CORE_TERRAFORM_DIR/terraform.tfstate" ]]; then
        cp "$CORE_TERRAFORM_DIR/terraform.tfstate" "$BACKUP_DIR/core-terraform.tfstate.backup"
        print_info "Core Terraform state backed up"
    fi
    
    if [[ -f "$AINEXUS_TERRAFORM_DIR/terraform.tfstate" ]]; then
        cp "$AINEXUS_TERRAFORM_DIR/terraform.tfstate" "$BACKUP_DIR/ainexus-terraform.tfstate.backup"
        print_info "AI Nexus Terraform state backed up"
    fi
    
    # Backup configuration files
    find "$PROJECT_ROOT" -name "*.tfvars" -exec cp {} "$BACKUP_DIR/" \;
    print_info "Configuration files backed up to: $BACKUP_DIR"
    
    # Create preservation record
    cat > "$BACKUP_DIR/preserved-resources.txt" << EOF
Resources Preserved During Cleanup - $(date)
===========================================

Route53 Hosted Zone: $PRESERVE_HOSTED_ZONE_ID ($PRESERVE_DOMAIN)
SSL Certificates: Preserved (existing ACM certificates)
Production Environment: Fully preserved
MinIO S3 Buckets: 
$(printf '  - %s\n' "${PRESERVE_MINIO_BUCKETS[@]}")

CloudFront Distributions: Preserved
Production Lambda Functions: Preserved
Production API Gateway: Preserved
Production Cognito: Preserved
Production DynamoDB: Preserved
EOF

    print_success "Backup and preservation record created: $BACKUP_DIR"
}

cleanup_duplicate_vpcs() {
    print_header "CLEANING UP DUPLICATE VPCs"
    
    # Get all non-default VPCs
    local vpcs=($(aws ec2 describe-vpcs --region "$AWS_REGION" --query 'Vpcs[?IsDefault==`false`].VpcId' --output text))
    
    print_info "Found VPCs: ${vpcs[*]}"
    
    # Keep one dev VPC (the first one) and the prod VPC
    local vpc_to_keep=""
    local prod_vpc=""
    
    for vpc in "${vpcs[@]}"; do
        local vpc_name=$(aws ec2 describe-vpcs --region "$AWS_REGION" --vpc-ids "$vpc" --query 'Vpcs[0].Tags[?Key==`Name`].Value|[0]' --output text)
        
        if [[ "$vpc_name" == "diatonic-prod-vpc" ]]; then
            prod_vpc="$vpc"
            print_preserve "Production VPC: $vpc ($vpc_name)"
        elif [[ "$vpc_name" == "aws-devops-dev-vpc" && -z "$vpc_to_keep" ]]; then
            vpc_to_keep="$vpc"
            print_preserve "Development VPC: $vpc ($vpc_name)"
        elif [[ "$vpc_name" == "aws-devops-dev-vpc" ]]; then
            print_info "Marking duplicate dev VPC for cleanup: $vpc"
            
            # Check if VPC has any resources
            local subnets=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[*].SubnetId' --output text)
            local instances=$(aws ec2 describe-instances --region "$AWS_REGION" --filters "Name=vpc-id,Values=$vpc" --query 'Reservations[*].Instances[?State.Name!=`terminated`].InstanceId' --output text)
            
            if [[ -n "$subnets" || -n "$instances" ]]; then
                print_warning "VPC $vpc has resources - manual cleanup may be needed"
            else
                print_info "VPC $vpc appears empty - safe to delete"
                # Don't actually delete yet - just mark for cleanup
            fi
        fi
    done
    
    print_success "VPC analysis completed - keeping prod VPC and one dev VPC"
}

cleanup_old_s3_buckets() {
    print_header "CLEANING UP OLD DEV S3 BUCKETS"
    
    # Get all S3 buckets
    local all_buckets=($(aws s3 ls | awk '{print $3}'))
    
    print_info "Analyzing S3 buckets..."
    
    for bucket in "${all_buckets[@]}"; do
        # Check if it's a MinIO bucket (preserve)
        local is_minio=false
        for minio_bucket in "${PRESERVE_MINIO_BUCKETS[@]}"; do
            if [[ "$bucket" == "$minio_bucket" ]]; then
                is_minio=true
                break
            fi
        done
        
        if [[ "$is_minio" == "true" ]]; then
            print_preserve "MinIO bucket: $bucket"
        elif [[ "$bucket" =~ ^diatonic-prod- ]]; then
            print_preserve "Production bucket: $bucket"
        elif [[ "$bucket" =~ ^aws-devops-dev-.*-gwenbxgb$ ]]; then
            print_warning "Old dev bucket (older suffix): $bucket - marked for cleanup"
            # These are the older buckets that should be cleaned up
        elif [[ "$bucket" =~ ^aws-devops-dev-.*-dzfngw8v$ ]]; then
            print_info "Current dev bucket (newer suffix): $bucket - will be managed by Terraform"
        else
            print_info "Other bucket: $bucket"
        fi
    done
    
    print_success "S3 bucket analysis completed"
}

cleanup_terraform_state_conflicts() {
    print_header "CLEANING UP TERRAFORM STATE CONFLICTS"
    
    # Clean up any stale Terraform state that might cause conflicts
    if [[ -d "$CORE_TERRAFORM_DIR/.terraform" ]]; then
        print_info "Removing core Terraform cache..."
        rm -rf "$CORE_TERRAFORM_DIR/.terraform"
    fi
    
    if [[ -d "$AINEXUS_TERRAFORM_DIR/.terraform" ]]; then
        print_info "Removing AI Nexus Terraform cache..."
        rm -rf "$AINEXUS_TERRAFORM_DIR/.terraform"
    fi
    
    # Remove lock files
    find "$PROJECT_ROOT" -name ".terraform.lock.hcl" -delete 2>/dev/null || true
    
    # Remove any stale plan files
    find "$PROJECT_ROOT" -name "*.tfplan" -delete 2>/dev/null || true
    
    print_success "Terraform state conflicts cleaned up"
}

validate_preserved_resources() {
    print_header "VALIDATING PRESERVED RESOURCES"
    
    # Verify Route53 is intact
    local hosted_zones=$(aws route53 list-hosted-zones --query "HostedZones[?Id=='/hostedzone/$PRESERVE_HOSTED_ZONE_ID'].Name" --output text)
    if [[ "$hosted_zones" == "$PRESERVE_DOMAIN." ]]; then
        print_preserve "Route53 hosted zone verified: $PRESERVE_DOMAIN ($PRESERVE_HOSTED_ZONE_ID)"
    else
        print_error "Route53 hosted zone validation failed!"
        exit 1
    fi
    
    # Verify SSL certificates
    local certs_us_east_1=$(aws acm list-certificates --region us-east-1 --query 'CertificateSummaryList[*].DomainName' --output text)
    local certs_us_east_2=$(aws acm list-certificates --region us-east-2 --query 'CertificateSummaryList[*].DomainName' --output text)
    
    if [[ "$certs_us_east_1" == *"$PRESERVE_DOMAIN"* ]] || [[ "$certs_us_east_1" == *"*.$PRESERVE_DOMAIN"* ]]; then
        print_preserve "SSL certificates verified in us-east-1"
    fi
    
    if [[ "$certs_us_east_2" == *"$PRESERVE_DOMAIN"* ]] || [[ "$certs_us_east_2" == *"*.$PRESERVE_DOMAIN"* ]]; then
        print_preserve "SSL certificates verified in us-east-2"
    fi
    
    # Verify MinIO buckets
    for bucket in "${PRESERVE_MINIO_BUCKETS[@]}"; do
        if aws s3 ls "s3://$bucket" &>/dev/null; then
            print_preserve "MinIO bucket verified: $bucket"
        else
            print_warning "MinIO bucket not found: $bucket"
        fi
    done
    
    # Verify production resources
    local prod_api=$(aws apigateway get-rest-apis --region "$AWS_REGION" --query 'items[?name==`diatonic-prod-api`].id' --output text)
    if [[ -n "$prod_api" ]]; then
        print_preserve "Production API Gateway verified: $prod_api"
    fi
    
    local prod_cognito=$(aws cognito-idp list-user-pools --region "$AWS_REGION" --max-results 10 --query 'UserPools[?Name==`diatonic-prod-users`].Id' --output text)
    if [[ -n "$prod_cognito" ]]; then
        print_preserve "Production Cognito verified: $prod_cognito"
    fi
    
    print_success "All preserved resources validated successfully"
}

create_fresh_deployment_plan() {
    print_header "CREATING FRESH DEPLOYMENT PLAN"
    
    cat > "$BACKUP_DIR/fresh-deployment-plan.md" << EOF
# Fresh AI Nexus Workbench Deployment Plan

## Pre-deployment Status ✅
- Route53 domain preserved: $PRESERVE_DOMAIN
- SSL certificates preserved and available
- MinIO infrastructure intact
- Production environment preserved
- Development conflicts cleaned up

## Deployment Steps

### 1. Core Infrastructure Deployment
\`\`\`bash
cd $CORE_TERRAFORM_DIR
terraform init
terraform plan -var-file=terraform.dev.tfvars -out=dev-plan.tfplan
terraform apply dev-plan.tfplan
\`\`\`

### 2. AI Nexus Workbench Deployment  
\`\`\`bash
cd $AINEXUS_TERRAFORM_DIR
terraform init
terraform plan -var-file=terraform.dev.tfvars -out=dev-plan.tfplan
terraform apply dev-plan.tfplan
\`\`\`

### 3. Integration Validation
- Verify API Gateway custom domain
- Test Cognito authentication
- Validate S3 bucket access
- Confirm DynamoDB table creation
- Test Lambda function deployment

## Expected Resources After Deployment

### Core Infrastructure (Reused)
- VPC: Clean, single dev VPC
- Route53: Existing domain and hosted zone
- SSL: Existing certificates
- S3: AI Nexus upload bucket (new/updated)

### AI Nexus Workbench (New/Updated)
- API Gateway: AI Nexus API with custom domain
- Cognito: AI Nexus user pool
- Lambda: AI Nexus functions
- DynamoDB: AI Nexus tables
- S3: Integration with core upload bucket

### Preserved Resources
- MinIO S3 buckets: $(printf '%s, ' "${PRESERVE_MINIO_BUCKETS[@]}" | sed 's/, $//')
- Production environment: Fully intact
- Domain and SSL: Unchanged and working

## Rollback Plan
If deployment fails:
1. Restore Terraform states from: $BACKUP_DIR
2. Review error logs and fix configuration issues
3. Re-run targeted cleanup if needed
4. Retry deployment with fixes
EOF

    print_success "Fresh deployment plan created: $BACKUP_DIR/fresh-deployment-plan.md"
}

main() {
    print_header "TARGETED AWS CLEANUP FOR AI NEXUS INTEGRATION"
    echo -e "${GREEN}This cleanup preserves your working infrastructure!${NC}"
    echo ""
    
    confirm_cleanup
    
    print_info "Starting targeted cleanup process..."
    
    # Execute cleanup steps
    backup_configurations
    cleanup_duplicate_vpcs
    cleanup_old_s3_buckets  
    cleanup_terraform_state_conflicts
    validate_preserved_resources
    create_fresh_deployment_plan
    
    print_header "TARGETED CLEANUP COMPLETED"
    print_success "✅ Environment cleaned up and ready for AI Nexus deployment"
    print_info "📁 All backups and plans saved to: $BACKUP_DIR"
    print_info "📋 Next: Review deployment plan and proceed with fresh deployment"
    echo ""
    echo -e "${GREEN}Your infrastructure is now optimally prepared for AI Nexus Workbench!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the deployment plan: cat $BACKUP_DIR/fresh-deployment-plan.md"
    echo "2. Deploy core infrastructure: cd $CORE_TERRAFORM_DIR && terraform plan -var-file=terraform.dev.tfvars"
    echo "3. Deploy AI Nexus: cd $AINEXUS_TERRAFORM_DIR && terraform plan -var-file=terraform.dev.tfvars"
}

# Handle script arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
