#!/bin/bash
# Import Missing Conflicting AWS Resources into Terraform State
# This script imports ONLY the missing resources that are causing conflicts

set -e

REGION="us-east-2"
PREFIX="aws-devops-dev"
TERRAFORM_DIR="/home/daclab-ai/dev/AWS-DevOps/infrastructure/terraform/core"

echo "🔄 Importing missing conflicting AWS resources into Terraform state..."
echo "Region: $REGION"
echo "Prefix: $PREFIX"
echo "Terraform Directory: $TERRAFORM_DIR"

cd "$TERRAFORM_DIR"

# Function to safely import a resource
safe_import() {
    local resource_address="$1"
    local resource_id="$2"
    local resource_name="$3"
    
    echo "📥 Importing $resource_name..."
    
    if terraform import "$resource_address" "$resource_id" -var-file="terraform.dev.tfvars" 2>/dev/null; then
        echo "✅ Successfully imported $resource_name"
    else
        echo "⚠️  Failed to import $resource_name (may already be imported or not exist)"
    fi
}

echo -e "\n🔍 Discovering missing resource IDs..."

# Get Load Balancer ARN
LB_ARN=$(aws elbv2 describe-load-balancers \
    --names "${PREFIX}-alb" \
    --region "$REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || echo "")

# Get Target Group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
    --names "${PREFIX}-tg" \
    --region "$REGION" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "")

# Get ECS Cluster Name
ECS_CLUSTER_EXISTS=$(aws ecs describe-clusters \
    --clusters "${PREFIX}-cluster" \
    --region "$REGION" \
    --query 'clusters[0].status' \
    --output text 2>/dev/null || echo "")

# Get ECS Service
ECS_SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster "${PREFIX}-cluster" \
    --services "${PREFIX}-service" \
    --region "$REGION" \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "")

# Get ECS Task Definition ARN (most recent)
TASK_DEF_ARN=$(aws ecs describe-task-definition \
    --task-definition "${PREFIX}" \
    --region "$REGION" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text 2>/dev/null || echo "")

echo "📋 Found conflicting resources:"
echo "  - Load Balancer: ${LB_ARN:0:50}..."
echo "  - Target Group: ${TG_ARN:0:50}..."
echo "  - ECS Cluster: $ECS_CLUSTER_EXISTS"
echo "  - ECS Service: $ECS_SERVICE_EXISTS" 
echo "  - Task Definition: ${TASK_DEF_ARN:0:50}..."

echo -e "\n🏗️  Starting targeted imports..."

# Import Load Balancer resources
if [[ "$LB_ARN" != "" && "$LB_ARN" != "null" ]]; then
    safe_import "module.web_application.aws_lb.main" "$LB_ARN" "Application Load Balancer"
fi

if [[ "$TG_ARN" != "" && "$TG_ARN" != "null" ]]; then
    safe_import "module.web_application.aws_lb_target_group.main" "$TG_ARN" "Target Group"
fi

# Import ECS resources
if [[ "$ECS_CLUSTER_EXISTS" == "ACTIVE" ]]; then
    safe_import "module.web_application.aws_ecs_cluster.main" "${PREFIX}-cluster" "ECS Cluster"
fi

if [[ "$ECS_SERVICE_EXISTS" == "ACTIVE" ]]; then
    safe_import "module.web_application.aws_ecs_service.main" "${PREFIX}-cluster/${PREFIX}-service" "ECS Service"
fi

if [[ "$TASK_DEF_ARN" != "" && "$TASK_DEF_ARN" != "null" ]]; then
    safe_import "module.web_application.aws_ecs_task_definition.main" "$TASK_DEF_ARN" "ECS Task Definition"
fi

# Import IAM roles that exist
echo -e "\n🔒 Importing IAM roles..."
safe_import "module.web_application.aws_iam_role.ecs_task_role" "${PREFIX}-ecs-task-role" "ECS Task Role"
safe_import "module.web_application.aws_iam_role.ecs_execution_role" "${PREFIX}-ecs-execution-role" "ECS Execution Role"

# Import CloudWatch Log Group
echo -e "\n📊 Importing CloudWatch resources..."
safe_import "module.web_application.aws_cloudwatch_log_group.main[0]" "/ecs/${PREFIX}" "ECS Log Group"

# Import VPC-related resources that may be missing
echo -e "\n🌐 Importing VPC-related missing resources..."

# Import database and cache subnet groups
safe_import "module.vpc.aws_db_subnet_group.main" "${PREFIX}-db-subnet-group" "DB Subnet Group"
safe_import "module.vpc.aws_elasticache_subnet_group.main" "${PREFIX}-cache-subnet-group" "ElastiCache Subnet Group"

# Import VPC flow log role if it exists
VPC_FLOW_ROLE_EXISTS=$(aws iam get-role --role-name "${PREFIX}-vpc-flow-log-role" 2>/dev/null && echo "true" || echo "false")
if [[ "$VPC_FLOW_ROLE_EXISTS" == "true" ]]; then
    safe_import "module.vpc.aws_iam_role.flow_log[0]" "${PREFIX}-vpc-flow-log-role" "VPC Flow Logs Role"
fi

# Import CloudWatch log group for VPC flow logs
safe_import "module.vpc.aws_cloudwatch_log_group.vpc_flow_log[0]" "/aws/vpc/flowlogs/${PREFIX}" "VPC Flow Logs CloudWatch Group"

# Import KMS alias  
safe_import "module.s3.aws_kms_alias.s3_key_alias[0]" "alias/${PREFIX}-s3-development" "KMS S3 Alias"

echo -e "\n✅ Import process completed!"
echo ""
echo "📋 Next steps:"
echo "1. Run 'terraform plan' to see if there are remaining conflicts"
echo "2. If conflicts remain, identify any missed resources and import them"
echo "3. Once plan is clean, you can run 'terraform apply' to create missing resources"
echo ""
echo "⚠️  Note: This script focused only on the major conflicting resources."
echo "   Additional resources may need to be imported if conflicts persist."
