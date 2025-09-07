#!/bin/bash
# Import Existing AWS Resources into Terraform State
# This script imports existing AWS resources to match the current deployment

set -e

REGION="us-east-2"
PREFIX="aws-devops-dev"
TERRAFORM_DIR="/home/daclab-ai/dev/AWS-DevOps/infrastructure/terraform/core"

echo "🔄 Importing existing AWS resources into Terraform state..."
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
    
    if terraform import "$resource_address" "$resource_id" 2>/dev/null; then
        echo "✅ Successfully imported $resource_name"
    else
        echo "⚠️  Failed to import $resource_name (may already be imported or not exist)"
    fi
}

# Function to get resource ID
get_resource_id() {
    local query_command="$1"
    eval "$query_command" 2>/dev/null || echo ""
}

echo -e "\n🔍 Discovering existing resource IDs..."

# Get the active VPC ID (the one used by the load balancer)
VPC_ID=$(aws elbv2 describe-load-balancers \
    --names "${PREFIX}-alb" \
    --region "$REGION" \
    --query 'LoadBalancers[0].VpcId' \
    --output text 2>/dev/null || echo "")

echo "Active VPC ID (from Load Balancer): $VPC_ID"

# Get subnet IDs from the active VPC
PUBLIC_SUBNET_1=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-public-subnet-1" \
    --region "$REGION" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "")

PUBLIC_SUBNET_2=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-public-subnet-2" \
    --region "$REGION" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "")

PUBLIC_SUBNET_3=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-public-subnet-3" \
    --region "$REGION" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "")

PRIVATE_SUBNET_1=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-private-subnet-1" \
    --region "$REGION" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "")

PRIVATE_SUBNET_2=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-private-subnet-2" \
    --region "$REGION" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "")

PRIVATE_SUBNET_3=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-private-subnet-3" \
    --region "$REGION" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "")

# Get data subnets
DATA_SUBNET_1=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-data-subnet-1" \
    --region "$REGION" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "")

DATA_SUBNET_2=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-data-subnet-2" \
    --region "$REGION" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "")

DATA_SUBNET_3=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-data-subnet-3" \
    --region "$REGION" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "")

echo "Discovered subnets:"
echo "  Public: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2, $PUBLIC_SUBNET_3"
echo "  Private: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2, $PRIVATE_SUBNET_3"
echo "  Data: $DATA_SUBNET_1, $DATA_SUBNET_2, $DATA_SUBNET_3"

# Get Internet Gateway ID
IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=${PREFIX}-igw" \
    --region "$REGION" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text 2>/dev/null || echo "")

# Get NAT Gateway ID
NAT_GW_ID=$(aws ec2 describe-nat-gateways \
    --filter "Name=tag:Name,Values=${PREFIX}-natgw" \
    --region "$REGION" \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2>/dev/null || echo "")

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

# Get Security Group IDs
ALB_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${PREFIX}-alb-*" \
    --region "$REGION" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "")

ECS_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${PREFIX}-ecs-tasks-*" \
    --region "$REGION" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "")

# Get ECS Cluster ARN
ECS_CLUSTER_ARN=$(aws ecs describe-clusters \
    --clusters "${PREFIX}-cluster" \
    --region "$REGION" \
    --query 'clusters[0].clusterArn' \
    --output text 2>/dev/null || echo "")

# Get ECS Service ARN
ECS_SERVICE_ARN=$(aws ecs describe-services \
    --cluster "${PREFIX}-cluster" \
    --services "${PREFIX}-service" \
    --region "$REGION" \
    --query 'services[0].serviceArn' \
    --output text 2>/dev/null || echo "")

# Get ECS Task Definition ARN
TASK_DEF_ARN=$(aws ecs describe-task-definition \
    --task-definition "${PREFIX}" \
    --region "$REGION" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text 2>/dev/null || echo "")

echo -e "\n🏗️  Starting Terraform imports..."

# Import VPC module resources
if [[ "$VPC_ID" != "" && "$VPC_ID" != "null" ]]; then
    safe_import "module.vpc.aws_vpc.main" "$VPC_ID" "VPC"
    
    # Import public subnets (3 AZs)
    [[ "$PUBLIC_SUBNET_1" != "" ]] && safe_import "module.vpc.aws_subnet.public[0]" "$PUBLIC_SUBNET_1" "Public Subnet 1 (us-east-2a)"
    [[ "$PUBLIC_SUBNET_2" != "" ]] && safe_import "module.vpc.aws_subnet.public[1]" "$PUBLIC_SUBNET_2" "Public Subnet 2 (us-east-2b)"
    [[ "$PUBLIC_SUBNET_3" != "" ]] && safe_import "module.vpc.aws_subnet.public[2]" "$PUBLIC_SUBNET_3" "Public Subnet 3 (us-east-2c)"
    
    # Import private subnets (3 AZs)
    [[ "$PRIVATE_SUBNET_1" != "" ]] && safe_import "module.vpc.aws_subnet.private[0]" "$PRIVATE_SUBNET_1" "Private Subnet 1 (us-east-2a)"
    [[ "$PRIVATE_SUBNET_2" != "" ]] && safe_import "module.vpc.aws_subnet.private[1]" "$PRIVATE_SUBNET_2" "Private Subnet 2 (us-east-2b)"
    [[ "$PRIVATE_SUBNET_3" != "" ]] && safe_import "module.vpc.aws_subnet.private[2]" "$PRIVATE_SUBNET_3" "Private Subnet 3 (us-east-2c)"
    
    # Import data subnets (3 AZs)
    [[ "$DATA_SUBNET_1" != "" ]] && safe_import "module.vpc.aws_subnet.data[0]" "$DATA_SUBNET_1" "Data Subnet 1 (us-east-2a)"
    [[ "$DATA_SUBNET_2" != "" ]] && safe_import "module.vpc.aws_subnet.data[1]" "$DATA_SUBNET_2" "Data Subnet 2 (us-east-2b)"
    [[ "$DATA_SUBNET_3" != "" ]] && safe_import "module.vpc.aws_subnet.data[2]" "$DATA_SUBNET_3" "Data Subnet 3 (us-east-2c)"
    
    # Import Internet Gateway
    [[ "$IGW_ID" != "" ]] && safe_import "module.vpc.aws_internet_gateway.main" "$IGW_ID" "Internet Gateway"
    
    # Import NAT Gateway (only for AZ1 in dev environment)
    [[ "$NAT_GW_ID" != "" ]] && safe_import "module.vpc.aws_nat_gateway.main[0]" "$NAT_GW_ID" "NAT Gateway"
    
    # Import route tables
    RT_PUBLIC_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-public-rt" --region "$REGION" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || echo "")
    [[ "$RT_PUBLIC_ID" != "" ]] && safe_import "module.vpc.aws_route_table.public" "$RT_PUBLIC_ID" "Public Route Table"
    
    RT_PRIVATE_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-private-rt-1" --region "$REGION" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || echo "")
    [[ "$RT_PRIVATE_ID" != "" ]] && safe_import "module.vpc.aws_route_table.private[0]" "$RT_PRIVATE_ID" "Private Route Table"
    
    RT_DATA_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PREFIX}-data-rt" --region "$REGION" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || echo "")
    [[ "$RT_DATA_ID" != "" ]] && safe_import "module.vpc.aws_route_table.data" "$RT_DATA_ID" "Data Route Table"
fi

# Import Security Groups
[[ "$ALB_SG_ID" != "" ]] && safe_import "module.web_application.aws_security_group.alb" "$ALB_SG_ID" "ALB Security Group"
[[ "$ECS_SG_ID" != "" ]] && safe_import "module.web_application.aws_security_group.ecs_tasks" "$ECS_SG_ID" "ECS Tasks Security Group"

# Import Load Balancer resources
[[ "$LB_ARN" != "" ]] && safe_import "module.web_application.aws_lb.main" "$LB_ARN" "Application Load Balancer"
[[ "$TG_ARN" != "" ]] && safe_import "module.web_application.aws_lb_target_group.main" "$TG_ARN" "Target Group"

# Import ECS resources
[[ "$ECS_CLUSTER_ARN" != "" ]] && safe_import "module.web_application.aws_ecs_cluster.main" "${PREFIX}-cluster" "ECS Cluster"
[[ "$ECS_SERVICE_ARN" != "" ]] && safe_import "module.web_application.aws_ecs_service.main" "${PREFIX}-cluster/${PREFIX}-service" "ECS Service"
[[ "$TASK_DEF_ARN" != "" ]] && safe_import "module.web_application.aws_ecs_task_definition.main" "$TASK_DEF_ARN" "ECS Task Definition"

# Import IAM roles
echo -e "\n🔒 Importing IAM roles..."
safe_import "module.web_application.aws_iam_role.ecs_task_role" "${PREFIX}-ecs-task-role" "ECS Task Role"
safe_import "module.web_application.aws_iam_role.ecs_execution_role" "${PREFIX}-ecs-execution-role" "ECS Execution Role"

# VPC Flow logs role (if exists)
VPC_FLOW_ROLE_EXISTS=$(aws iam get-role --role-name "${PREFIX}-vpc-flow-log-role" 2>/dev/null && echo "true" || echo "false")
if [[ "$VPC_FLOW_ROLE_EXISTS" == "true" ]]; then
    safe_import "module.vpc.aws_iam_role.flow_logs[0]" "${PREFIX}-vpc-flow-log-role" "VPC Flow Logs Role"
fi

# Import CloudWatch Log Groups
echo -e "\n📊 Importing CloudWatch resources..."
safe_import "module.web_application.aws_cloudwatch_log_group.main[0]" "/ecs/${PREFIX}" "ECS Log Group"

# Import S3 resources
echo -e "\n🗄️  Importing S3 resources..."
S3_BUCKET_NAME="${PREFIX}-web-content-$(date +%s)"
# Note: You'll need to adjust this based on your actual S3 bucket name
# safe_import "module.s3_web_hosting.aws_s3_bucket.web_hosting" "$S3_BUCKET_NAME" "S3 Web Hosting Bucket"

echo -e "\n✅ Import process completed!"
echo ""
echo "📋 Next steps:"
echo "1. Run 'terraform plan' to see if there are any configuration drifts"
echo "2. Update Terraform configuration files to match the actual resource settings"
echo "3. Run 'terraform plan' again to ensure no changes are needed"
echo "4. You can now manage these resources with Terraform!"
echo ""
echo "⚠️  Note: Some resources may need manual configuration adjustments"
echo "   to match the exact settings of your deployed infrastructure."
