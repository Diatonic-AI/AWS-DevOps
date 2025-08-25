#!/bin/bash

# AWS Free Tier Usage Monitoring Script
# This script checks your current AWS usage against free tier limits

set -e

echo "🔍 AWS Free Tier Usage Monitor"
echo "=============================="
echo "Account: $(aws sts get-caller-identity --query Account --output text)"
echo "Region: $(aws configure get region)"
echo "Date: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to calculate percentage
calculate_percentage() {
    local used=$1
    local limit=$2
    if [ "$limit" -gt 0 ]; then
        echo "scale=2; ($used / $limit) * 100" | bc -l
    else
        echo "0"
    fi
}

# Function to print usage status
print_usage_status() {
    local service=$1
    local used=$2
    local limit=$3
    local unit=$4
    
    local percentage
    percentage=$(calculate_percentage "$used" "$limit")
    
    printf "%-20s: %s/%s %s" "$service" "$used" "$limit" "$unit"
    
    if (( $(echo "$percentage > 80" | bc -l) )); then
        printf " ${RED}(%.1f%% - WARNING!)${NC}\n" "$percentage"
    elif (( $(echo "$percentage > 50" | bc -l) )); then
        printf " ${YELLOW}(%.1f%%)${NC}\n" "$percentage"
    else
        printf " ${GREEN}(%.1f%%)${NC}\n" "$percentage"
    fi
}

echo "📊 EC2 INSTANCES (Free Tier: 750 hours/month)"
echo "----------------------------------------------"

# Check EC2 instances
ec2_instances=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,InstanceType,LaunchTime]' \
    --output json)

if [ "$ec2_instances" = "[]" ]; then
    echo "✅ No running EC2 instances"
else
    echo "$ec2_instances" | jq -r '.[] | "Instance: \(.[0]) Type: \(.[1]) Launch: \(.[2])"'
    
    # Count free tier eligible instances
    free_tier_instances=$(echo "$ec2_instances" | jq -r '.[] | select(.[1] == "t2.micro" or .[1] == "t3.micro") | .[0]' | wc -l)
    echo "Free tier eligible instances running: $free_tier_instances"
fi

echo ""

echo "💾 S3 STORAGE (Free Tier: 5GB Standard Storage)"
echo "---------------------------------------------"

# Check S3 buckets and usage
buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)

if [ -z "$buckets" ]; then
    echo "✅ No S3 buckets found"
else
    total_size=0
    for bucket in $buckets; do
        # Get bucket size (this is an approximation)
        size=$(aws s3 ls "s3://$bucket" --recursive --human-readable --summarize | grep "Total Size" | awk '{print $3}')
        echo "Bucket: $bucket - Size: ${size:-0}"
    done
fi

echo ""

echo "🗄️ RDS INSTANCES (Free Tier: 750 hours/month db.t2.micro)"
echo "--------------------------------------------------------"

# Check RDS instances
rds_instances=$(aws rds describe-db-instances \
    --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus,AllocatedStorage]' \
    --output json)

if [ "$rds_instances" = "[]" ]; then
    echo "✅ No RDS instances found"
else
    echo "$rds_instances" | jq -r '.[] | "Instance: \(.[0]) Class: \(.[1]) Status: \(.[2]) Storage: \(.[3])GB"'
fi

echo ""

echo "⚡ LAMBDA FUNCTIONS (Free Tier: 1M requests, 400K GB-seconds)"
echo "----------------------------------------------------------"

# Check Lambda functions
lambda_functions=$(aws lambda list-functions --query 'Functions[].FunctionName' --output text)

if [ -z "$lambda_functions" ]; then
    echo "✅ No Lambda functions found"
else
    function_count=$(echo "$lambda_functions" | wc -w)
    echo "Total Lambda functions: $function_count"
    
    # List functions
    for func in $lambda_functions; do
        echo "Function: $func"
    done
fi

echo ""

echo "🔔 CLOUDWATCH (Free Tier: 10 custom metrics, 10 alarms)"
echo "-----------------------------------------------------"

# Check CloudWatch alarms
alarm_count=$(aws cloudwatch describe-alarms --query 'MetricAlarms | length(@)' --output text)
print_usage_status "CloudWatch Alarms" "$alarm_count" "10" "alarms"

echo ""

echo "🌐 API GATEWAY (Free Tier: 1M API calls/month)"
echo "--------------------------------------------"

# Check API Gateway
apis=$(aws apigateway get-rest-apis --query 'items[].name' --output text)

if [ -z "$apis" ]; then
    echo "✅ No API Gateway APIs found"
else
    api_count=$(echo "$apis" | wc -w)
    echo "Total APIs: $api_count"
fi

echo ""

echo "💰 CURRENT MONTH ESTIMATED CHARGES"
echo "===================================="

# Get current month's charges
current_month=$(date +%Y-%m-01)
next_month=$(date -d "$current_month +1 month" +%Y-%m-01)

if command_exists bc; then
    charges=$(aws ce get-cost-and-usage \
        --time-period Start="$current_month",End="$next_month" \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
        --output text 2>/dev/null || echo "0.00")
    
    printf "Current estimated charges: $%.2f USD\n" "$charges"
    
    if (( $(echo "$charges > 1.00" | bc -l) )); then
        echo -e "${RED}⚠️  WARNING: You may have exceeded free tier limits!${NC}"
    elif (( $(echo "$charges > 0.50" | bc -l) )); then
        echo -e "${YELLOW}⚠️  CAUTION: Approaching free tier limits${NC}"
    else
        echo -e "${GREEN}✅ Well within free tier limits${NC}"
    fi
else
    echo "Install 'bc' calculator for charge calculations"
fi

echo ""

echo "📋 RECOMMENDATIONS"
echo "=================="
echo "1. Monitor your usage regularly (weekly recommended)"
echo "2. Set up billing alerts at \$0.01, \$1.00, and \$5.00"
echo "3. Tag resources with 'Project=FreeTier' for tracking"
echo "4. Use AWS Cost Explorer for detailed cost analysis"
echo "5. Delete unused resources immediately"
echo "6. Stop EC2 instances when not needed"
echo ""

echo "📞 USEFUL COMMANDS"
echo "=================="
echo "Set up billing alert:"
echo "aws budgets create-budget --account-id \$(aws sts get-caller-identity --query Account --output text) --budget '{\"BudgetName\":\"FreeTier\",\"TimeUnit\":\"MONTHLY\",\"BudgetLimit\":{\"Amount\":\"1\",\"Unit\":\"USD\"},\"BudgetType\":\"COST\"}'"
echo ""
echo "Check costs in detail:"
echo "aws ce get-cost-and-usage --time-period Start=$(date +%Y-%m-01),End=$(date -d 'next month' +%Y-%m-01) --granularity DAILY --metrics BlendedCost"
echo ""

echo "✅ Free Tier monitoring complete!"
echo "Last updated: $(date)"
