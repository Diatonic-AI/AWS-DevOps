#!/bin/bash
#
# MMP Toledo Resource Tagging Script
# Tags all MMP Toledo and Firespring resources with proper client organization identifiers
#

set -e

# Color output for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# MMP Toledo Account Details
MMP_TOLEDO_ACCOUNT_ID="455303857245"
MMP_TOLEDO_OU_ID="ou-295b-jwnuwyen"
CURRENT_ACCOUNT_ID="313476888312"

# Common tags for all MMP Toledo resources
MMP_TOLEDO_TAGS=(
    "ClientOrganization=MMP-Toledo"
    "ClientAccount=${MMP_TOLEDO_ACCOUNT_ID}"
    "ClientName=Minute Man Press Toledo"
    "ClientOU=${MMP_TOLEDO_OU_ID}"
    "BillingProject=mmp-toledo"
    "ManagedBy=terraform"
    "AssignedBy=aws-cli"
    "AssignedDate=$(date -u +%Y-%m-%d)"
)

# Common tags for Firespring integration resources (also belong to MMP Toledo)
FIRESPRING_TAGS=(
    "ClientOrganization=MMP-Toledo"
    "ClientAccount=${MMP_TOLEDO_ACCOUNT_ID}"
    "ClientName=Minute Man Press Toledo"
    "ClientOU=${MMP_TOLEDO_OU_ID}"
    "BillingProject=mmp-toledo-firespring"
    "IntegrationPartner=Firespring"
    "ManagedBy=terraform"
    "AssignedBy=aws-cli"
    "AssignedDate=$(date -u +%Y-%m-%d)"
)

# Function to convert array of tags to AWS tag format
tags_to_aws_format() {
    local tags=("$@")
    local result=""
    for tag in "${tags[@]}"; do
        if [ -n "$result" ]; then
            result="${result},"
        fi
        key="${tag%%=*}"
        value="${tag#*=}"
        result="${result}{Key=${key},Value=${value}}"
    done
    echo "$result"
}

# Function to tag Lambda function
tag_lambda() {
    local function_name=$1
    local region=$2
    shift 2
    local tags=("$@")

    echo -e "${BLUE}Tagging Lambda: ${function_name} (${region})${NC}"

    local function_arn="arn:aws:lambda:${region}:${CURRENT_ACCOUNT_ID}:function:${function_name}"
    local tag_string=""
    for tag in "${tags[@]}"; do
        key="${tag%%=*}"
        value="${tag#*=}"
        if [ -n "$tag_string" ]; then
            tag_string="${tag_string},"
        fi
        tag_string="${tag_string}${key}=${value}"
    done

    aws lambda tag-resource \
        --resource "${function_arn}" \
        --tags "${tag_string}" \
        --region "${region}" 2>&1 || echo -e "${YELLOW}Warning: Failed to tag ${function_name}${NC}"
}

# Function to tag DynamoDB table
tag_dynamodb() {
    local table_name=$1
    local region=$2
    shift 2
    local tags=("$@")

    echo -e "${BLUE}Tagging DynamoDB: ${table_name} (${region})${NC}"

    local table_arn="arn:aws:dynamodb:${region}:${CURRENT_ACCOUNT_ID}:table/${table_name}"
    local tag_array="["
    local first=true
    for tag in "${tags[@]}"; do
        key="${tag%%=*}"
        value="${tag#*=}"
        if [ "$first" = true ]; then
            first=false
        else
            tag_array="${tag_array},"
        fi
        tag_array="${tag_array}{Key=${key},Value=${value}}"
    done
    tag_array="${tag_array}]"

    aws dynamodb tag-resource \
        --resource-arn "${table_arn}" \
        --tags "${tag_array}" \
        --region "${region}" 2>&1 || echo -e "${YELLOW}Warning: Failed to tag ${table_name}${NC}"
}

# Function to tag S3 bucket
tag_s3() {
    local bucket_name=$1
    shift
    local tags=("$@")

    echo -e "${BLUE}Tagging S3 Bucket: ${bucket_name}${NC}"

    local tag_set="TagSet=["
    local first=true
    for tag in "${tags[@]}"; do
        key="${tag%%=*}"
        value="${tag#*=}"
        if [ "$first" = true ]; then
            first=false
        else
            tag_set="${tag_set},"
        fi
        tag_set="${tag_set}{Key=${key},Value=${value}}"
    done
    tag_set="${tag_set}]"

    aws s3api put-bucket-tagging \
        --bucket "${bucket_name}" \
        --tagging "${tag_set}" 2>&1 || echo -e "${YELLOW}Warning: Failed to tag ${bucket_name}${NC}"
}

# Function to tag API Gateway (REST API)
tag_api_gateway_rest() {
    local api_id=$1
    local region=$2
    shift 2
    local tags=("$@")

    echo -e "${BLUE}Tagging API Gateway REST API: ${api_id} (${region})${NC}"

    local tag_obj="{"
    local first=true
    for tag in "${tags[@]}"; do
        key="${tag%%=*}"
        value="${tag#*=}"
        if [ "$first" = true ]; then
            first=false
        else
            tag_obj="${tag_obj},"
        fi
        tag_obj="${tag_obj}\"${key}\":\"${value}\""
    done
    tag_obj="${tag_obj}}"

    aws apigateway tag-resource \
        --resource-arn "arn:aws:apigateway:${region}::/restapis/${api_id}" \
        --tags "${tag_obj}" \
        --region "${region}" 2>&1 || echo -e "${YELLOW}Warning: Failed to tag REST API ${api_id}${NC}"
}

# Function to tag API Gateway (HTTP API v2)
tag_api_gateway_v2() {
    local api_id=$1
    local region=$2
    shift 2
    local tags=("$@")

    echo -e "${BLUE}Tagging API Gateway HTTP API: ${api_id} (${region})${NC}"

    local tag_obj="{"
    local first=true
    for tag in "${tags[@]}"; do
        key="${tag%%=*}"
        value="${tag#*=}"
        if [ "$first" = true ]; then
            first=false
        else
            tag_obj="${tag_obj},"
        fi
        tag_obj="${tag_obj}\"${key}\":\"${value}\""
    done
    tag_obj="${tag_obj}}"

    aws apigatewayv2 tag-resource \
        --resource-arn "arn:aws:apigateway:${region}::/apis/${api_id}" \
        --tags "${tag_obj}" \
        --region "${region}" 2>&1 || echo -e "${YELLOW}Warning: Failed to tag HTTP API ${api_id}${NC}"
}

# Function to tag Amplify App
tag_amplify() {
    local app_id=$1
    local region=$2
    shift 2
    local tags=("$@")

    echo -e "${BLUE}Tagging Amplify App: ${app_id} (${region})${NC}"

    local app_arn="arn:aws:amplify:${region}:${CURRENT_ACCOUNT_ID}:apps/${app_id}"
    local tag_obj="{"
    local first=true
    for tag in "${tags[@]}"; do
        key="${tag%%=*}"
        value="${tag#*=}"
        if [ "$first" = true ]; then
            first=false
        else
            tag_obj="${tag_obj},"
        fi
        tag_obj="${tag_obj}\"${key}\":\"${value}\""
    done
    tag_obj="${tag_obj}}"

    aws amplify tag-resource \
        --resource-arn "${app_arn}" \
        --tags "${tag_obj}" \
        --region "${region}" 2>&1 || echo -e "${YELLOW}Warning: Failed to tag Amplify app ${app_id}${NC}"
}

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}MMP Toledo Resource Tagging Script${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Current Account: ${CURRENT_ACCOUNT_ID}${NC}"
echo -e "${BLUE}MMP Toledo Account: ${MMP_TOLEDO_ACCOUNT_ID}${NC}"
echo -e "${BLUE}Client OU: ${MMP_TOLEDO_OU_ID}${NC}"
echo ""

# ========================================
# MMP TOLEDO CORE RESOURCES
# ========================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Tagging MMP Toledo Core Resources${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Amplify (us-east-2)
echo -e "${YELLOW}[1/5] Amplify Applications${NC}"
tag_amplify "dh9lr01l0snay" "us-east-2" "${MMP_TOLEDO_TAGS[@]}" "Component=Frontend" "Service=Amplify" "Environment=production"
echo ""

# Lambda Functions (us-east-1)
echo -e "${YELLOW}[2/5] Lambda Functions - Lead Management${NC}"
tag_lambda "mmp-toledo-leads-submit-lead" "us-east-1" "${MMP_TOLEDO_TAGS[@]}" "Component=LeadManagement" "Service=Lambda" "Environment=production"
tag_lambda "mmp-toledo-submit-lead" "us-east-1" "${MMP_TOLEDO_TAGS[@]}" "Component=LeadManagement" "Service=Lambda" "Environment=production"
tag_lambda "mmp-toledo-leads-otp-service" "us-east-1" "${MMP_TOLEDO_TAGS[@]}" "Component=OTPService" "Service=Lambda" "Environment=production"
tag_lambda "mmp-toledo-otp-service" "us-east-1" "${MMP_TOLEDO_TAGS[@]}" "Component=OTPService" "Service=Lambda" "Environment=production"
echo ""

# DynamoDB Tables (us-east-1)
echo -e "${YELLOW}[3/5] DynamoDB Tables${NC}"
tag_dynamodb "mmp-toledo-leads-otp-prod" "us-east-1" "${MMP_TOLEDO_TAGS[@]}" "Component=OTPStorage" "Service=DynamoDB" "Environment=production" "DataClassification=Sensitive"
tag_dynamodb "mmp-toledo-leads-prod" "us-east-1" "${MMP_TOLEDO_TAGS[@]}" "Component=LeadStorage" "Service=DynamoDB" "Environment=production" "DataClassification=PII"
tag_dynamodb "mmp-toledo-otp-prod" "us-east-1" "${MMP_TOLEDO_TAGS[@]}" "Component=OTPStorage" "Service=DynamoDB" "Environment=production" "DataClassification=Sensitive"
echo ""

# API Gateway (us-east-1)
echo -e "${YELLOW}[4/5] API Gateway APIs${NC}"
tag_api_gateway_rest "4rqx1r4jzi" "us-east-1" "${MMP_TOLEDO_TAGS[@]}" "Component=LeadAPI" "Service=APIGateway" "Environment=production" "APIType=REST"
tag_api_gateway_v2 "xnqz4ow8hi" "us-east-1" "${MMP_TOLEDO_TAGS[@]}" "Component=LeadAPI" "Service=APIGateway" "Environment=production" "APIType=HTTP"
echo ""

# S3 Buckets (us-east-2)
echo -e "${YELLOW}[5/5] S3 Buckets - Media Storage${NC}"
tag_s3 "mmp-toledo-shared-media" "${MMP_TOLEDO_TAGS[@]}" "Component=MediaStorage" "Service=S3" "Environment=production" "Branch=main"
tag_s3 "mmp-toledo-shared-media-develop" "${MMP_TOLEDO_TAGS[@]}" "Component=MediaStorage" "Service=S3" "Environment=development" "Branch=develop"
echo ""

# ========================================
# FIRESPRING INTEGRATION RESOURCES
# ========================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Tagging Firespring Integration Resources${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Lambda Functions (us-east-1)
echo -e "${YELLOW}[1/4] Lambda Functions - Data Pipeline${NC}"
tag_lambda "firespring-backdoor-orchestrator-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=Orchestration" "Service=Lambda" "Environment=development"
tag_lambda "firespring-backdoor-extractor-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=DataExtraction" "Service=Lambda" "Environment=development"
tag_lambda "firespring-backdoor-connector-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=APIConnection" "Service=Lambda" "Environment=development"
tag_lambda "firespring-backdoor-exporter-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=DataExport" "Service=Lambda" "Environment=development"
tag_lambda "firespring-backdoor-normalizer-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=DataNormalization" "Service=Lambda" "Environment=development"
echo ""

echo -e "${YELLOW}[2/4] Lambda Functions - System Management${NC}"
tag_lambda "firespring-backdoor-sync-handler-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=SyncManagement" "Service=Lambda" "Environment=development"
tag_lambda "firespring-backdoor-api-discovery-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=APIDiscovery" "Service=Lambda" "Environment=development"
tag_lambda "firespring-backdoor-health-checker-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=HealthMonitoring" "Service=Lambda" "Environment=development"
tag_lambda "firespring-backdoor-network-manager-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=NetworkManagement" "Service=Lambda" "Environment=development"
echo ""

# DynamoDB Tables (us-east-1)
echo -e "${YELLOW}[3/4] DynamoDB Tables${NC}"
tag_dynamodb "firespring-backdoor-actions-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=ActionTracking" "Service=DynamoDB" "Environment=development"
tag_dynamodb "firespring-backdoor-extraction-jobs-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=JobManagement" "Service=DynamoDB" "Environment=development"
tag_dynamodb "firespring-backdoor-network-state-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=NetworkState" "Service=DynamoDB" "Environment=development"
tag_dynamodb "firespring-backdoor-searches-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=SearchData" "Service=DynamoDB" "Environment=development"
tag_dynamodb "firespring-backdoor-segments-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=AnalyticsSegments" "Service=DynamoDB" "Environment=development"
tag_dynamodb "firespring-backdoor-traffic-sources-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=TrafficSources" "Service=DynamoDB" "Environment=development"
tag_dynamodb "firespring-backdoor-visitors-dev" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=VisitorAnalytics" "Service=DynamoDB" "Environment=development"
echo ""

# API Gateway HTTP API (us-east-1)
echo -e "${YELLOW}[4/4] API Gateway${NC}"
tag_api_gateway_v2 "apw8coizxk" "us-east-1" "${FIRESPRING_TAGS[@]}" "Component=DataAPI" "Service=APIGateway" "Environment=development" "APIType=HTTP"
echo ""

# S3 Buckets (region-agnostic)
echo -e "${YELLOW}[5/5] S3 Buckets${NC}"
tag_s3 "firespring-backdoor-data-30511389" "${FIRESPRING_TAGS[@]}" "Component=DataStorage" "Service=S3" "Environment=development"
tag_s3 "firespring-backdoor-lambda-30511389" "${FIRESPRING_TAGS[@]}" "Component=LambdaPackages" "Service=S3" "Environment=development"
echo ""

# ========================================
# COMPLETION
# ========================================

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Tagging Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  - MMP Toledo Core Resources: Tagged"
echo -e "    * 1 Amplify Application (us-east-2)"
echo -e "    * 4 Lambda Functions (us-east-1)"
echo -e "    * 3 DynamoDB Tables (us-east-1)"
echo -e "    * 2 API Gateway APIs (us-east-1)"
echo -e "    * 2 S3 Buckets (us-east-2)"
echo ""
echo -e "  - Firespring Integration Resources: Tagged"
echo -e "    * 9 Lambda Functions (us-east-1)"
echo -e "    * 7 DynamoDB Tables (us-east-1)"
echo -e "    * 1 API Gateway HTTP API (us-east-1)"
echo -e "    * 2 S3 Buckets"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Create Resource Groups for easier management"
echo -e "  2. Verify tags with: aws resourcegroupstaggingapi get-resources"
echo -e "  3. Generate cost allocation report"
echo ""
