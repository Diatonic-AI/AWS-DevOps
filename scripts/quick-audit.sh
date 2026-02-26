#!/bin/bash

# Quick AWS Resource Audit Script
# This script performs a safe audit of existing AWS resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-2}"

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

audit_resources() {
    print_header "AWS RESOURCE AUDIT"
    
    echo "Account: $(aws sts get-caller-identity --query Account --output text)"
    echo "Region: $AWS_REGION"
    echo "Time: $(date)"
    echo ""
    
    print_info "VPCs:"
    aws ec2 describe-vpcs --region "$AWS_REGION" --query 'Vpcs[*].[VpcId,CidrBlock,State,Tags[?Key==`Name`].Value|[0]]' --output table || true
    echo ""
    
    print_info "EC2 Instances:"
    aws ec2 describe-instances --region "$AWS_REGION" --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table || true
    echo ""
    
    print_info "ECS Clusters:"
    aws ecs list-clusters --region "$AWS_REGION" --output table || true
    echo ""
    
    print_info "Load Balancers:"
    aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn,State.Code]' --output table || true
    echo ""
    
    print_info "S3 Buckets:"
    aws s3 ls || true
    echo ""
    
    print_info "Lambda Functions:"
    aws lambda list-functions --region "$AWS_REGION" --query 'Functions[*].[FunctionName,Runtime,LastModified]' --output table || true
    echo ""
    
    print_info "API Gateways:"
    aws apigateway get-rest-apis --region "$AWS_REGION" --query 'items[*].[id,name,description]' --output table || true
    echo ""
    
    print_info "CloudFront Distributions:"
    aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName,Status]' --output table || true
    echo ""
    
    print_info "Route53 Hosted Zones:"
    aws route53 list-hosted-zones --query 'HostedZones[*].[Id,Name,ResourceRecordSetCount]' --output table || true
    echo ""
    
    print_info "Cognito User Pools:"
    aws cognito-idp list-user-pools --region "$AWS_REGION" --max-results 10 --query 'UserPools[*].[Id,Name,CreationDate]' --output table || true
    echo ""
    
    print_info "DynamoDB Tables:"
    aws dynamodb list-tables --region "$AWS_REGION" --query 'TableNames' --output table || true
    echo ""
    
    print_success "Resource audit completed"
}

main() {
    audit_resources
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
