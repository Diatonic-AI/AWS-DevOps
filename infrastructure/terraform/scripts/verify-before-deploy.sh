#!/bin/bash
# Pre-deployment verification script
# Checks for existing AWS resources that would conflict with Terraform

set -e

REGION="us-east-2"
PREFIX="aws-devops-dev"

echo "🔍 Pre-deployment verification for AWS DevOps infrastructure..."
echo "Region: $REGION"
echo "Prefix: $PREFIX"

CONFLICTS_FOUND=false

# Function to check for resource existence
check_resource() {
    local resource_type="$1"
    local check_command="$2"
    local resource_name="$3"
    
    if eval "$check_command" &>/dev/null; then
        echo "❌ CONFLICT: $resource_type '$resource_name' already exists"
        CONFLICTS_FOUND=true
    else
        echo "✅ $resource_type '$resource_name' - no conflict"
    fi
}

echo -e "\n🔀 Checking Load Balancer resources..."
check_resource "Application Load Balancer" \
    "aws elbv2 describe-load-balancers --names '${PREFIX}-alb' --region '$REGION'" \
    "${PREFIX}-alb"

check_resource "Target Group" \
    "aws elbv2 describe-target-groups --names '${PREFIX}-tg' --region '$REGION'" \
    "${PREFIX}-tg"

echo -e "\n🐳 Checking ECS resources..."
check_resource "ECS Cluster" \
    "aws ecs describe-clusters --clusters '${PREFIX}-cluster' --region '$REGION' | grep -q ACTIVE" \
    "${PREFIX}-cluster"

check_resource "ECS Service" \
    "aws ecs describe-services --cluster '${PREFIX}-cluster' --services '${PREFIX}-service' --region '$REGION' | grep -q ACTIVE" \
    "${PREFIX}-service"

echo -e "\n🔒 Checking IAM roles..."
check_resource "ECS Task Role" \
    "aws iam get-role --role-name '${PREFIX}-ecs-task-role'" \
    "${PREFIX}-ecs-task-role"

check_resource "ECS Execution Role" \
    "aws iam get-role --role-name '${PREFIX}-ecs-execution-role'" \
    "${PREFIX}-ecs-execution-role"

check_resource "VPC Flow Log Role" \
    "aws iam get-role --role-name '${PREFIX}-vpc-flow-log-role'" \
    "${PREFIX}-vpc-flow-log-role"

echo -e "\n📊 Checking CloudWatch log groups..."
check_resource "ECS Log Group" \
    "aws logs describe-log-groups --log-group-name-prefix '/ecs/${PREFIX}' --region '$REGION' | grep -q logGroupName" \
    "/ecs/${PREFIX}"

check_resource "VPC Flow Log Group" \
    "aws logs describe-log-groups --log-group-name-prefix '/aws/vpc/flowlogs/${PREFIX}' --region '$REGION' | grep -q logGroupName" \
    "/aws/vpc/flowlogs/${PREFIX}"

echo -e "\n🔐 Checking KMS aliases..."
check_resource "KMS Alias" \
    "aws kms describe-key --key-id 'alias/${PREFIX}-s3-development' --region '$REGION'" \
    "alias/${PREFIX}-s3-development"

echo -e "\n🗄️ Checking database subnet groups..."
check_resource "DB Subnet Group" \
    "aws rds describe-db-subnet-groups --db-subnet-group-name '${PREFIX}-db-subnet-group' --region '$REGION'" \
    "${PREFIX}-db-subnet-group"

check_resource "ElastiCache Subnet Group" \
    "aws elasticache describe-cache-subnet-groups --cache-subnet-group-name '${PREFIX}-cache-subnet-group' --region '$REGION'" \
    "${PREFIX}-cache-subnet-group"

echo -e "\n🛡️ Checking security groups..."
SG_COUNT=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${PREFIX}-*" \
    --region "$REGION" \
    --query 'length(SecurityGroups)' \
    --output text 2>/dev/null || echo "0")

if [[ "$SG_COUNT" -gt 0 ]]; then
    echo "❌ CONFLICT: $SG_COUNT security groups with prefix '${PREFIX}-' already exist"
    aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${PREFIX}-*" \
        --region "$REGION" \
        --query 'SecurityGroups[].[GroupName,GroupId]' \
        --output table
    CONFLICTS_FOUND=true
else
    echo "✅ Security groups with prefix '${PREFIX}-' - no conflicts"
fi

# Summary and recommendations
echo -e "\n📋 SUMMARY"
if [[ "$CONFLICTS_FOUND" == "true" ]]; then
    echo "❌ CONFLICTS DETECTED!"
    echo ""
    echo "🔧 RESOLUTION OPTIONS:"
    echo "1. 🗑️  CLEAN SLATE (Recommended for development):"
    echo "   ./scripts/cleanup-existing-resources.sh"
    echo ""
    echo "2. 📥 IMPORT EXISTING RESOURCES:"
    echo "   Use 'terraform import' commands to bring existing resources under Terraform management"
    echo ""
    echo "3. 🏷️  RENAME IN TERRAFORM:"
    echo "   Change resource names in Terraform configuration to avoid conflicts"
    echo ""
    echo "⚠️  You MUST resolve these conflicts before running 'terraform apply'"
else
    echo "✅ NO CONFLICTS DETECTED!"
    echo "🚀 You can proceed with Terraform deployment"
fi

# Exit with appropriate code
if [[ "$CONFLICTS_FOUND" == "true" ]]; then
    exit 1
else
    exit 0
fi
