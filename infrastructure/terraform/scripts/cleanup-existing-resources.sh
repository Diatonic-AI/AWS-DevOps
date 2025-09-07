#!/bin/bash
# Cleanup Existing AWS Resources Script
# This script removes existing AWS resources that conflict with Terraform deployment

set -e

REGION="us-east-2"
PREFIX="aws-devops-dev"

echo "🧹 Starting cleanup of existing AWS resources..."
echo "Region: $REGION"
echo "Prefix: $PREFIX"

# Function to safely delete a resource
safe_delete() {
    local resource_type="$1"
    local resource_name="$2"
    local delete_command="$3"
    
    echo "🗑️  Attempting to delete $resource_type: $resource_name"
    
    if eval "$delete_command" 2>/dev/null; then
        echo "✅ Successfully deleted $resource_type: $resource_name"
    else
        echo "⚠️  Failed to delete $resource_type: $resource_name (may not exist or have dependencies)"
    fi
}

# 1. Delete Load Balancer and Target Groups
echo -e "\n🔀 Cleaning up Load Balancer resources..."

# Get Load Balancer ARN
LB_ARN=$(aws elbv2 describe-load-balancers \
    --names "${PREFIX}-alb" \
    --region "$REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || echo "None")

if [[ "$LB_ARN" != "None" && "$LB_ARN" != "null" ]]; then
    # Delete listeners first
    echo "🔧 Deleting load balancer listeners..."
    aws elbv2 describe-listeners \
        --load-balancer-arn "$LB_ARN" \
        --region "$REGION" \
        --query 'Listeners[].ListenerArn' \
        --output text | xargs -n1 -I{} \
        aws elbv2 delete-listener --listener-arn {} --region "$REGION" 2>/dev/null || true
    
    # Delete load balancer
    safe_delete "Load Balancer" "${PREFIX}-alb" \
        "aws elbv2 delete-load-balancer --load-balancer-arn '$LB_ARN' --region '$REGION'"
    
    # Wait for load balancer deletion
    echo "⏳ Waiting for load balancer to be deleted..."
    aws elbv2 wait load-balancer-deleted --load-balancer-arn "$LB_ARN" --region "$REGION" 2>/dev/null || true
fi

# Delete Target Groups
echo "🎯 Deleting target groups..."
TG_ARNS=$(aws elbv2 describe-target-groups \
    --names "${PREFIX}-tg" \
    --region "$REGION" \
    --query 'TargetGroups[].TargetGroupArn' \
    --output text 2>/dev/null || echo "None")

if [[ "$TG_ARNS" != "None" && "$TG_ARNS" != "null" ]]; then
    for tg_arn in $TG_ARNS; do
        safe_delete "Target Group" "$tg_arn" \
            "aws elbv2 delete-target-group --target-group-arn '$tg_arn' --region '$REGION'"
    done
fi

# 2. Delete ECS Resources
echo -e "\n🐳 Cleaning up ECS resources..."

# Delete ECS Service
safe_delete "ECS Service" "${PREFIX}-service" \
    "aws ecs update-service --cluster '${PREFIX}-cluster' --service '${PREFIX}-service' --desired-count 0 --region '$REGION' && sleep 10 && aws ecs delete-service --cluster '${PREFIX}-cluster' --service '${PREFIX}-service' --region '$REGION'"

# Delete ECS Cluster
safe_delete "ECS Cluster" "${PREFIX}-cluster" \
    "aws ecs delete-cluster --cluster '${PREFIX}-cluster' --region '$REGION'"

# 3. Delete IAM Roles
echo -e "\n🔒 Cleaning up IAM roles..."

# Detach policies and delete ECS task role
TASK_ROLE="${PREFIX}-ecs-task-role"
echo "🗂️  Cleaning up IAM role: $TASK_ROLE"
aws iam list-attached-role-policies --role-name "$TASK_ROLE" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | \
    xargs -n1 -I{} aws iam detach-role-policy --role-name "$TASK_ROLE" --policy-arn {} 2>/dev/null || true
aws iam list-role-policies --role-name "$TASK_ROLE" --query 'PolicyNames[]' --output text 2>/dev/null | \
    xargs -n1 -I{} aws iam delete-role-policy --role-name "$TASK_ROLE" --policy-name {} 2>/dev/null || true
safe_delete "IAM Role" "$TASK_ROLE" "aws iam delete-role --role-name '$TASK_ROLE'"

# Detach policies and delete ECS execution role  
EXEC_ROLE="${PREFIX}-ecs-execution-role"
echo "🗂️  Cleaning up IAM role: $EXEC_ROLE"
aws iam list-attached-role-policies --role-name "$EXEC_ROLE" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | \
    xargs -n1 -I{} aws iam detach-role-policy --role-name "$EXEC_ROLE" --policy-arn {} 2>/dev/null || true
aws iam list-role-policies --role-name "$EXEC_ROLE" --query 'PolicyNames[]' --output text 2>/dev/null | \
    xargs -n1 -I{} aws iam delete-role-policy --role-name "$EXEC_ROLE" --policy-name {} 2>/dev/null || true
safe_delete "IAM Role" "$EXEC_ROLE" "aws iam delete-role --role-name '$EXEC_ROLE'"

# VPC Flow Log role
VPC_ROLE="${PREFIX}-vpc-flow-log-role"
echo "🗂️  Cleaning up IAM role: $VPC_ROLE"
aws iam list-attached-role-policies --role-name "$VPC_ROLE" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | \
    xargs -n1 -I{} aws iam detach-role-policy --role-name "$VPC_ROLE" --policy-arn {} 2>/dev/null || true
aws iam list-role-policies --role-name "$VPC_ROLE" --query 'PolicyNames[]' --output text 2>/dev/null | \
    xargs -n1 -I{} aws iam delete-role-policy --role-name "$VPC_ROLE" --policy-name {} 2>/dev/null || true
safe_delete "IAM Role" "$VPC_ROLE" "aws iam delete-role --role-name '$VPC_ROLE'"

# 4. Delete CloudWatch Log Groups
echo -e "\n📊 Cleaning up CloudWatch log groups..."
safe_delete "CloudWatch Log Group" "/ecs/${PREFIX}" \
    "aws logs delete-log-group --log-group-name '/ecs/${PREFIX}' --region '$REGION'"

safe_delete "CloudWatch Log Group" "/aws/vpc/flowlogs/${PREFIX}" \
    "aws logs delete-log-group --log-group-name '/aws/vpc/flowlogs/${PREFIX}' --region '$REGION'"

# 5. Delete KMS Aliases
echo -e "\n🔐 Cleaning up KMS aliases..."
safe_delete "KMS Alias" "alias/${PREFIX}-s3-development" \
    "aws kms delete-alias --alias-name 'alias/${PREFIX}-s3-development' --region '$REGION'"

# 6. Delete DB and ElastiCache Subnet Groups
echo -e "\n🗄️  Cleaning up database subnet groups..."
safe_delete "DB Subnet Group" "${PREFIX}-db-subnet-group" \
    "aws rds delete-db-subnet-group --db-subnet-group-name '${PREFIX}-db-subnet-group' --region '$REGION'"

safe_delete "ElastiCache Subnet Group" "${PREFIX}-cache-subnet-group" \
    "aws elasticache delete-cache-subnet-group --cache-subnet-group-name '${PREFIX}-cache-subnet-group' --region '$REGION'"

# 7. Delete Security Groups (after dependencies are removed)
echo -e "\n🛡️  Cleaning up security groups..."
# Wait a bit for resources to be cleaned up
echo "⏳ Waiting 30 seconds for resource cleanup to complete..."
sleep 30

# Get and delete ECS security groups
SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${PREFIX}-*" \
    --region "$REGION" \
    --query 'SecurityGroups[].GroupId' \
    --output text 2>/dev/null || echo "None")

if [[ "$SG_IDS" != "None" && "$SG_IDS" != "null" ]]; then
    for sg_id in $SG_IDS; do
        SG_NAME=$(aws ec2 describe-security-groups --group-ids "$sg_id" --region "$REGION" --query 'SecurityGroups[0].GroupName' --output text 2>/dev/null || echo "unknown")
        safe_delete "Security Group" "$SG_NAME ($sg_id)" \
            "aws ec2 delete-security-group --group-id '$sg_id' --region '$REGION'"
    done
fi

echo -e "\n✅ Cleanup completed!"
echo "🔍 If you see warnings above, they likely indicate resources that didn't exist or had dependencies."
echo "🚀 You can now proceed with the Terraform deployment."
