#!/bin/bash
# Inspect Current AWS Deployment
# Discovers and documents the exact configuration of currently deployed resources

set -e

REGION="us-east-2"
PREFIX="aws-devops-dev"

echo "🔍 Inspecting current AWS deployment..."
echo "Region: $REGION"
echo "Prefix: $PREFIX"

# Create output file
REPORT_FILE="/tmp/aws_deployment_inspection_$(date +%Y%m%d_%H%M%S).json"
echo "📋 Report will be saved to: $REPORT_FILE"

# Initialize JSON report
cat > "$REPORT_FILE" << EOF
{
  "inspection_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "region": "$REGION",
  "prefix": "$PREFIX",
  "resources": {}
}
EOF

# Function to add resource info to report
add_to_report() {
    local resource_type="$1"
    local resource_data="$2"
    
    jq --arg type "$resource_type" --argjson data "$resource_data" \
       '.resources[$type] = $data' "$REPORT_FILE" > "$REPORT_FILE.tmp" && \
       mv "$REPORT_FILE.tmp" "$REPORT_FILE"
}

echo -e "\n🌐 Inspecting VPC and Networking..."

# VPC Information
VPC_DATA=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Project,Values=aws-devops" \
    --region "$REGION" \
    --output json 2>/dev/null || echo '{"Vpcs":[]}')

if [[ $(echo "$VPC_DATA" | jq '.Vpcs | length') -gt 0 ]]; then
    VPC_ID=$(echo "$VPC_DATA" | jq -r '.Vpcs[0].VpcId')
    echo "✅ Found VPC: $VPC_ID"
    add_to_report "vpc" "$VPC_DATA"
    
    # Get subnets
    SUBNET_DATA=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --region "$REGION" \
        --output json 2>/dev/null || echo '{"Subnets":[]}')
    add_to_report "subnets" "$SUBNET_DATA"
    
    # Get route tables
    ROUTE_TABLE_DATA=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --region "$REGION" \
        --output json 2>/dev/null || echo '{"RouteTables":[]}')
    add_to_report "route_tables" "$ROUTE_TABLE_DATA"
    
    # Get Internet Gateway
    IGW_DATA=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --region "$REGION" \
        --output json 2>/dev/null || echo '{"InternetGateways":[]}')
    add_to_report "internet_gateways" "$IGW_DATA"
    
    # Get NAT Gateways
    NAT_DATA=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=$VPC_ID" \
        --region "$REGION" \
        --output json 2>/dev/null || echo '{"NatGateways":[]}')
    add_to_report "nat_gateways" "$NAT_DATA"
    
    # Get Security Groups
    SG_DATA=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --region "$REGION" \
        --output json 2>/dev/null || echo '{"SecurityGroups":[]}')
    add_to_report "security_groups" "$SG_DATA"
else
    echo "❌ No VPC found with Project tag: aws-devops"
fi

echo -e "\n🔀 Inspecting Load Balancer..."
LB_DATA=$(aws elbv2 describe-load-balancers \
    --names "${PREFIX}-alb" \
    --region "$REGION" \
    --output json 2>/dev/null || echo '{"LoadBalancers":[]}')

if [[ $(echo "$LB_DATA" | jq '.LoadBalancers | length') -gt 0 ]]; then
    LB_ARN=$(echo "$LB_DATA" | jq -r '.LoadBalancers[0].LoadBalancerArn')
    echo "✅ Found Load Balancer: $LB_ARN"
    add_to_report "load_balancers" "$LB_DATA"
    
    # Get listeners
    LISTENER_DATA=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$LB_ARN" \
        --region "$REGION" \
        --output json 2>/dev/null || echo '{"Listeners":[]}')
    add_to_report "listeners" "$LISTENER_DATA"
fi

# Target Groups
TG_DATA=$(aws elbv2 describe-target-groups \
    --names "${PREFIX}-tg" \
    --region "$REGION" \
    --output json 2>/dev/null || echo '{"TargetGroups":[]}')
add_to_report "target_groups" "$TG_DATA"

echo -e "\n🐳 Inspecting ECS Resources..."

# ECS Cluster
ECS_CLUSTER_DATA=$(aws ecs describe-clusters \
    --clusters "${PREFIX}-cluster" \
    --region "$REGION" \
    --output json 2>/dev/null || echo '{"clusters":[]}')
add_to_report "ecs_clusters" "$ECS_CLUSTER_DATA"

# ECS Services
ECS_SERVICE_DATA=$(aws ecs describe-services \
    --cluster "${PREFIX}-cluster" \
    --services "${PREFIX}-service" \
    --region "$REGION" \
    --output json 2>/dev/null || echo '{"services":[]}')
add_to_report "ecs_services" "$ECS_SERVICE_DATA"

# ECS Task Definition
TASK_DEF_DATA=$(aws ecs describe-task-definition \
    --task-definition "${PREFIX}" \
    --region "$REGION" \
    --output json 2>/dev/null || echo '{"taskDefinition":{}}')
add_to_report "ecs_task_definitions" "$TASK_DEF_DATA"

echo -e "\n🔒 Inspecting IAM Roles..."

# IAM Roles
ROLE_NAMES=("${PREFIX}-ecs-task-role" "${PREFIX}-ecs-execution-role" "${PREFIX}-vpc-flow-log-role")
for role_name in "${ROLE_NAMES[@]}"; do
    ROLE_DATA=$(aws iam get-role --role-name "$role_name" --output json 2>/dev/null || echo '{}')
    if [[ "$ROLE_DATA" != '{}' ]]; then
        echo "✅ Found IAM Role: $role_name"
        
        # Get attached policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$role_name" --output json 2>/dev/null || echo '{"AttachedPolicies":[]}')
        
        # Get inline policies
        INLINE_POLICIES=$(aws iam list-role-policies --role-name "$role_name" --output json 2>/dev/null || echo '{"PolicyNames":[]}')
        
        # Combine role info
        COMBINED_ROLE_DATA=$(echo "$ROLE_DATA" | jq --argjson attached "$ATTACHED_POLICIES" --argjson inline "$INLINE_POLICIES" \
            '.Role.AttachedPolicies = $attached.AttachedPolicies | .Role.InlinePolicies = $inline.PolicyNames')
        
        add_to_report "iam_role_${role_name}" "$COMBINED_ROLE_DATA"
    fi
done

echo -e "\n📊 Inspecting CloudWatch Resources..."

# CloudWatch Log Groups
LOG_GROUPS=("/ecs/${PREFIX}" "/aws/vpc/flowlogs/${PREFIX}")
for log_group in "${LOG_GROUPS[@]}"; do
    LOG_GROUP_DATA=$(aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --output json 2>/dev/null || echo '{"logGroups":[]}')
    if [[ $(echo "$LOG_GROUP_DATA" | jq '.logGroups | length') -gt 0 ]]; then
        echo "✅ Found Log Group: $log_group"
        add_to_report "log_group_$(echo $log_group | tr '/' '_')" "$LOG_GROUP_DATA"
    fi
done

echo -e "\n🔐 Inspecting KMS Resources..."

# KMS Keys
KMS_ALIAS="alias/${PREFIX}-s3-development"
KMS_DATA=$(aws kms describe-key --key-id "$KMS_ALIAS" --region "$REGION" --output json 2>/dev/null || echo '{}')
if [[ "$KMS_DATA" != '{}' ]]; then
    echo "✅ Found KMS Key: $KMS_ALIAS"
    add_to_report "kms_key" "$KMS_DATA"
fi

echo -e "\n🗄️ Inspecting Database Resources..."

# RDS Subnet Group
DB_SUBNET_GROUP_DATA=$(aws rds describe-db-subnet-groups --db-subnet-group-name "${PREFIX}-db-subnet-group" --region "$REGION" --output json 2>/dev/null || echo '{"DBSubnetGroups":[]}')
add_to_report "db_subnet_groups" "$DB_SUBNET_GROUP_DATA"

# ElastiCache Subnet Group
CACHE_SUBNET_GROUP_DATA=$(aws elasticache describe-cache-subnet-groups --cache-subnet-group-name "${PREFIX}-cache-subnet-group" --region "$REGION" --output json 2>/dev/null || echo '{"CacheSubnetGroups":[]}')
add_to_report "cache_subnet_groups" "$CACHE_SUBNET_GROUP_DATA"

echo -e "\n🗃️ Inspecting S3 Resources..."

# List S3 buckets with prefix
S3_BUCKETS=$(aws s3api list-buckets --output json 2>/dev/null | jq --arg prefix "${PREFIX}" '.Buckets[] | select(.Name | startswith($prefix))' || echo '{}')
if [[ "$S3_BUCKETS" != '{}' ]]; then
    echo "✅ Found S3 buckets"
    add_to_report "s3_buckets" "[$S3_BUCKETS]"
fi

echo -e "\n✅ Inspection completed!"
echo "📋 Full report saved to: $REPORT_FILE"

# Generate human-readable summary
echo -e "\n📊 SUMMARY:"
echo "===================="

# Count resources
VPC_COUNT=$(jq '.resources.vpc.Vpcs | length' "$REPORT_FILE" 2>/dev/null || echo 0)
SUBNET_COUNT=$(jq '.resources.subnets.Subnets | length' "$REPORT_FILE" 2>/dev/null || echo 0)
LB_COUNT=$(jq '.resources.load_balancers.LoadBalancers | length' "$REPORT_FILE" 2>/dev/null || echo 0)
ECS_CLUSTER_COUNT=$(jq '.resources.ecs_clusters.clusters | length' "$REPORT_FILE" 2>/dev/null || echo 0)
ECS_SERVICE_COUNT=$(jq '.resources.ecs_services.services | length' "$REPORT_FILE" 2>/dev/null || echo 0)

echo "🌐 VPCs: $VPC_COUNT"
echo "🌐 Subnets: $SUBNET_COUNT" 
echo "🔀 Load Balancers: $LB_COUNT"
echo "🐳 ECS Clusters: $ECS_CLUSTER_COUNT"
echo "🐳 ECS Services: $ECS_SERVICE_COUNT"

# Show key resource IDs
if [[ $VPC_COUNT -gt 0 ]]; then
    VPC_ID=$(jq -r '.resources.vpc.Vpcs[0].VpcId' "$REPORT_FILE")
    echo "📋 VPC ID: $VPC_ID"
fi

if [[ $LB_COUNT -gt 0 ]]; then
    LB_DNS=$(jq -r '.resources.load_balancers.LoadBalancers[0].DNSName' "$REPORT_FILE")
    echo "🌐 Load Balancer DNS: $LB_DNS"
fi

echo -e "\n🔧 Use this information to adjust the import script as needed."
echo "📄 Review the full JSON report for detailed configurations."
