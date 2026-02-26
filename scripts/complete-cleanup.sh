#!/bin/bash

# Complete AWS Environment Cleanup Script
# WARNING: This script will DESTROY ALL resources in your AWS account
# Use with extreme caution - this is irreversible!

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
BACKUP_DIR="$PROJECT_ROOT/cleanup-backups-$(date +%Y%m%d-%H%M%S)"

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

confirm_destruction() {
    local resource_type="$1"
    echo -e "${RED}WARNING: This will PERMANENTLY DESTROY all $resource_type${NC}"
    echo -e "${YELLOW}This action is IRREVERSIBLE!${NC}"
    echo ""
    read -p "Type 'DESTROY' in all caps to confirm: " confirmation
    if [[ "$confirmation" != "DESTROY" ]]; then
        print_info "Operation cancelled"
        exit 0
    fi
}

backup_terraform_state() {
    print_header "BACKING UP TERRAFORM STATES"
    mkdir -p "$BACKUP_DIR"
    
    # Backup core infrastructure state
    if [[ -f "$CORE_TERRAFORM_DIR/terraform.tfstate" ]]; then
        cp "$CORE_TERRAFORM_DIR/terraform.tfstate" "$BACKUP_DIR/core-terraform.tfstate.backup"
        print_info "Core Terraform state backed up"
    fi
    
    # Backup AI Nexus state
    if [[ -f "$AINEXUS_TERRAFORM_DIR/terraform.tfstate" ]]; then
        cp "$AINEXUS_TERRAFORM_DIR/terraform.tfstate" "$BACKUP_DIR/ainexus-terraform.tfstate.backup"
        print_info "AI Nexus Terraform state backed up"
    fi
    
    # Backup important configuration files
    find "$PROJECT_ROOT" -name "*.tfvars" -exec cp {} "$BACKUP_DIR/" \;
    print_info "Configuration files backed up to: $BACKUP_DIR"
}

audit_existing_resources() {
    print_header "AUDITING EXISTING AWS RESOURCES"
    
    local audit_file="$BACKUP_DIR/aws-resource-audit.txt"
    
    echo "AWS Resource Audit - $(date)" > "$audit_file"
    echo "Account: $(aws sts get-caller-identity --query Account --output text)" >> "$audit_file"
    echo "Region: $AWS_REGION" >> "$audit_file"
    echo "===========================================" >> "$audit_file"
    
    print_info "Scanning VPCs..."
    echo "" >> "$audit_file"
    echo "VPCs:" >> "$audit_file"
    aws ec2 describe-vpcs --region "$AWS_REGION" --query 'Vpcs[*].[VpcId,CidrBlock,State,Tags[?Key==`Name`].Value|[0]]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning EC2 instances..."
    echo "" >> "$audit_file"
    echo "EC2 Instances:" >> "$audit_file"
    aws ec2 describe-instances --region "$AWS_REGION" --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning RDS instances..."
    echo "" >> "$audit_file"
    echo "RDS Instances:" >> "$audit_file"
    aws rds describe-db-instances --region "$AWS_REGION" --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning ECS clusters..."
    echo "" >> "$audit_file"
    echo "ECS Clusters:" >> "$audit_file"
    aws ecs list-clusters --region "$AWS_REGION" --query 'clusterArns' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning Load Balancers..."
    echo "" >> "$audit_file"
    echo "Application Load Balancers:" >> "$audit_file"
    aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn,State.Code]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning S3 buckets..."
    echo "" >> "$audit_file"
    echo "S3 Buckets:" >> "$audit_file"
    aws s3 ls >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning Lambda functions..."
    echo "" >> "$audit_file"
    echo "Lambda Functions:" >> "$audit_file"
    aws lambda list-functions --region "$AWS_REGION" --query 'Functions[*].[FunctionName,Runtime,LastModified]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning API Gateways..."
    echo "" >> "$audit_file"
    echo "API Gateways:" >> "$audit_file"
    aws apigateway get-rest-apis --region "$AWS_REGION" --query 'items[*].[id,name,description]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning CloudFront distributions..."
    echo "" >> "$audit_file"
    echo "CloudFront Distributions:" >> "$audit_file"
    aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName,Status]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning Route53 hosted zones..."
    echo "" >> "$audit_file"
    echo "Route53 Hosted Zones:" >> "$audit_file"
    aws route53 list-hosted-zones --query 'HostedZones[*].[Id,Name,ResourceRecordSetCount]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning ACM certificates..."
    echo "" >> "$audit_file"
    echo "ACM Certificates:" >> "$audit_file"
    aws acm list-certificates --region "$AWS_REGION" --query 'CertificateSummaryList[*].[CertificateArn,DomainName,Status]' --output table >> "$audit_file" 2>/dev/null || true
    aws acm list-certificates --region us-east-1 --query 'CertificateSummaryList[*].[CertificateArn,DomainName,Status]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning Cognito User Pools..."
    echo "" >> "$audit_file"
    echo "Cognito User Pools:" >> "$audit_file"
    aws cognito-idp list-user-pools --region "$AWS_REGION" --max-results 10 --query 'UserPools[*].[Id,Name,CreationDate]' --output table >> "$audit_file" 2>/dev/null || true
    
    print_info "Scanning DynamoDB tables..."
    echo "" >> "$audit_file"
    echo "DynamoDB Tables:" >> "$audit_file"
    aws dynamodb list-tables --region "$AWS_REGION" --query 'TableNames' --output table >> "$audit_file" 2>/dev/null || true
    
    print_success "Resource audit completed: $audit_file"
    echo ""
    echo "Review the audit file to understand what will be destroyed:"
    echo "cat $audit_file"
    echo ""
}

destroy_terraform_managed_resources() {
    print_header "DESTROYING TERRAFORM-MANAGED RESOURCES"
    
    # Destroy AI Nexus Workbench first (application layer)
    if [[ -d "$AINEXUS_TERRAFORM_DIR" ]]; then
        print_info "Destroying AI Nexus Workbench infrastructure..."
        cd "$AINEXUS_TERRAFORM_DIR"
        
        if [[ -f "terraform.dev.tfvars" ]]; then
            confirm_destruction "AI Nexus Workbench resources"
            terraform destroy -var-file="terraform.dev.tfvars" -auto-approve || {
                print_warning "Some AI Nexus resources may have failed to destroy - continuing with manual cleanup"
            }
            print_success "AI Nexus Workbench destruction completed"
        else
            print_warning "No AI Nexus tfvars file found - skipping Terraform destroy"
        fi
    fi
    
    # Destroy core infrastructure last (foundation layer)
    if [[ -d "$CORE_TERRAFORM_DIR" ]]; then
        print_info "Destroying core infrastructure..."
        cd "$CORE_TERRAFORM_DIR"
        
        if [[ -f "terraform.dev.tfvars" ]]; then
            confirm_destruction "core infrastructure resources"
            terraform destroy -var-file="terraform.dev.tfvars" -auto-approve || {
                print_warning "Some core resources may have failed to destroy - continuing with manual cleanup"
            }
            print_success "Core infrastructure destruction completed"
        else
            print_warning "No core tfvars file found - skipping Terraform destroy"
        fi
    fi
}

manual_resource_cleanup() {
    print_header "MANUAL CLEANUP OF REMAINING RESOURCES"
    
    print_info "Cleaning up ECS services and tasks..."
    
    # Stop all ECS services
    local clusters=$(aws ecs list-clusters --region "$AWS_REGION" --query 'clusterArns[]' --output text)
    for cluster in $clusters; do
        if [[ -n "$cluster" ]]; then
            local services=$(aws ecs list-services --region "$AWS_REGION" --cluster "$cluster" --query 'serviceArns[]' --output text)
            for service in $services; do
                if [[ -n "$service" ]]; then
                    print_info "Stopping ECS service: $service"
                    aws ecs update-service --region "$AWS_REGION" --cluster "$cluster" --service "$service" --desired-count 0 || true
                    aws ecs delete-service --region "$AWS_REGION" --cluster "$cluster" --service "$service" || true
                fi
            done
            
            print_info "Deleting ECS cluster: $cluster"
            aws ecs delete-cluster --region "$AWS_REGION" --cluster "$cluster" || true
        fi
    done
    
    print_info "Cleaning up Lambda functions..."
    local functions=$(aws lambda list-functions --region "$AWS_REGION" --query 'Functions[*].FunctionName' --output text)
    for func in $functions; do
        if [[ -n "$func" ]]; then
            print_info "Deleting Lambda function: $func"
            aws lambda delete-function --region "$AWS_REGION" --function-name "$func" || true
        fi
    done
    
    print_info "Cleaning up API Gateways..."
    local apis=$(aws apigateway get-rest-apis --region "$AWS_REGION" --query 'items[*].id' --output text)
    for api in $apis; do
        if [[ -n "$api" ]]; then
            print_info "Deleting API Gateway: $api"
            aws apigateway delete-rest-api --region "$AWS_REGION" --rest-api-id "$api" || true
        fi
    done
    
    print_info "Cleaning up CloudFront distributions..."
    local distributions=$(aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,Status]' --output text)
    while read -r dist_id status; do
        if [[ -n "$dist_id" && "$status" == "Deployed" ]]; then
            print_info "Disabling CloudFront distribution: $dist_id"
            local etag=$(aws cloudfront get-distribution --id "$dist_id" --query 'ETag' --output text)
            aws cloudfront get-distribution-config --id "$dist_id" --query 'DistributionConfig' > /tmp/dist-config.json
            jq '.Enabled = false' /tmp/dist-config.json > /tmp/dist-config-disabled.json
            aws cloudfront update-distribution --id "$dist_id" --distribution-config file:///tmp/dist-config-disabled.json --if-match "$etag" || true
        fi
    done <<< "$distributions"
    
    print_info "Emptying and deleting S3 buckets..."
    local buckets=$(aws s3 ls | awk '{print $3}')
    for bucket in $buckets; do
        if [[ -n "$bucket" ]]; then
            print_info "Emptying S3 bucket: $bucket"
            aws s3 rm s3://"$bucket" --recursive || true
            
            # Remove all object versions and delete markers
            aws s3api list-object-versions --bucket "$bucket" --query 'Versions[*].[Key,VersionId]' --output text | while read key version; do
                if [[ -n "$key" && -n "$version" ]]; then
                    aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version" || true
                fi
            done
            
            aws s3api list-object-versions --bucket "$bucket" --query 'DeleteMarkers[*].[Key,VersionId]' --output text | while read key version; do
                if [[ -n "$key" && -n "$version" ]]; then
                    aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version" || true
                fi
            done
            
            print_info "Deleting S3 bucket: $bucket"
            aws s3api delete-bucket --bucket "$bucket" || true
        fi
    done
    
    print_info "Cleaning up Cognito User Pools..."
    local pools=$(aws cognito-idp list-user-pools --region "$AWS_REGION" --max-results 10 --query 'UserPools[*].Id' --output text)
    for pool in $pools; do
        if [[ -n "$pool" ]]; then
            print_info "Deleting Cognito User Pool: $pool"
            aws cognito-idp delete-user-pool --region "$AWS_REGION" --user-pool-id "$pool" || true
        fi
    done
    
    print_info "Cleaning up DynamoDB tables..."
    local tables=$(aws dynamodb list-tables --region "$AWS_REGION" --query 'TableNames[]' --output text)
    for table in $tables; do
        if [[ -n "$table" ]]; then
            print_info "Deleting DynamoDB table: $table"
            aws dynamodb delete-table --region "$AWS_REGION" --table-name "$table" || true
        fi
    done
    
    print_success "Manual cleanup completed"
}

cleanup_terraform_state() {
    print_header "CLEANING UP TERRAFORM STATE FILES"
    
    # Remove Terraform state files (they're already backed up)
    if [[ -f "$CORE_TERRAFORM_DIR/terraform.tfstate" ]]; then
        rm -f "$CORE_TERRAFORM_DIR/terraform.tfstate"
        rm -f "$CORE_TERRAFORM_DIR/terraform.tfstate.backup"
        print_info "Core Terraform state files removed"
    fi
    
    if [[ -f "$AINEXUS_TERRAFORM_DIR/terraform.tfstate" ]]; then
        rm -f "$AINEXUS_TERRAFORM_DIR/terraform.tfstate"
        rm -f "$AINEXUS_TERRAFORM_DIR/terraform.tfstate.backup"
        print_info "AI Nexus Terraform state files removed"
    fi
    
    # Remove plan files
    find "$PROJECT_ROOT" -name "*.tfplan" -delete
    
    # Remove Terraform lock files
    find "$PROJECT_ROOT" -name ".terraform.lock.hcl" -delete
    
    # Remove .terraform directories
    find "$PROJECT_ROOT" -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Terraform state cleanup completed"
}

verify_cleanup() {
    print_header "VERIFYING COMPLETE CLEANUP"
    
    local verification_file="$BACKUP_DIR/cleanup-verification.txt"
    
    echo "AWS Cleanup Verification - $(date)" > "$verification_file"
    echo "Account: $(aws sts get-caller-identity --query Account --output text)" >> "$verification_file"
    echo "Region: $AWS_REGION" >> "$verification_file"
    echo "===========================================" >> "$verification_file"
    
    # Check for remaining resources
    local has_resources=false
    
    print_info "Checking for remaining VPCs..."
    local vpcs=$(aws ec2 describe-vpcs --region "$AWS_REGION" --query 'Vpcs[?IsDefault==`false`]' --output text)
    if [[ -n "$vpcs" ]]; then
        echo "Remaining VPCs found!" >> "$verification_file"
        aws ec2 describe-vpcs --region "$AWS_REGION" --query 'Vpcs[?IsDefault==`false`].[VpcId,CidrBlock,State]' --output table >> "$verification_file"
        has_resources=true
    fi
    
    print_info "Checking for remaining EC2 instances..."
    local instances=$(aws ec2 describe-instances --region "$AWS_REGION" --query 'Reservations[*].Instances[?State.Name!=`terminated`]' --output text)
    if [[ -n "$instances" ]]; then
        echo "Remaining EC2 instances found!" >> "$verification_file"
        aws ec2 describe-instances --region "$AWS_REGION" --query 'Reservations[*].Instances[?State.Name!=`terminated`].[InstanceId,State.Name]' --output table >> "$verification_file"
        has_resources=true
    fi
    
    print_info "Checking for remaining S3 buckets..."
    local buckets=$(aws s3 ls)
    if [[ -n "$buckets" ]]; then
        echo "Remaining S3 buckets found!" >> "$verification_file"
        echo "$buckets" >> "$verification_file"
        has_resources=true
    fi
    
    print_info "Checking for remaining Lambda functions..."
    local functions=$(aws lambda list-functions --region "$AWS_REGION" --query 'Functions[*].FunctionName' --output text)
    if [[ -n "$functions" ]]; then
        echo "Remaining Lambda functions found!" >> "$verification_file"
        echo "$functions" >> "$verification_file"
        has_resources=true
    fi
    
    if [[ "$has_resources" == "false" ]]; then
        print_success "✅ CLEANUP VERIFICATION PASSED - No managed resources remain"
        echo "✅ CLEANUP VERIFICATION PASSED" >> "$verification_file"
    else
        print_warning "⚠️  Some resources may still exist - check verification file"
        echo "⚠️  Some resources may still exist" >> "$verification_file"
    fi
    
    print_info "Verification report: $verification_file"
}

main() {
    print_header "AWS COMPLETE ENVIRONMENT CLEANUP"
    echo -e "${RED}⚠️  WARNING: This will DESTROY ALL AWS resources in your account!${NC}"
    echo -e "${YELLOW}Make sure you have backed up any important data!${NC}"
    echo ""
    
    # Final confirmation
    confirm_destruction "ALL AWS RESOURCES"
    
    # Execute cleanup steps
    backup_terraform_state
    audit_existing_resources
    destroy_terraform_managed_resources
    manual_resource_cleanup
    cleanup_terraform_state
    verify_cleanup
    
    print_header "CLEANUP COMPLETED"
    print_success "✅ AWS environment cleanup completed"
    print_info "📁 All backups and reports saved to: $BACKUP_DIR"
    print_info "🔍 Review verification report before proceeding with fresh deployment"
    echo ""
    echo -e "${GREEN}Your AWS environment is now clean and ready for fresh deployment!${NC}"
}

# Handle script arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
