#!/bin/bash
#
# Fix DynamoDB and S3 Tagging for MMP Toledo Resources
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

MMP_TOLEDO_ACCOUNT_ID="455303857245"
MMP_TOLEDO_OU_ID="ou-295b-jwnuwyen"
CURRENT_ACCOUNT_ID="313476888312"
CURRENT_DATE=$(date -u +%Y-%m-%d)

# Function to tag DynamoDB table (corrected format)
tag_dynamodb() {
    local table_name=$1
    local region=$2
    shift 2

    echo -e "${BLUE}Tagging DynamoDB: ${table_name} (${region})${NC}"

    local table_arn="arn:aws:dynamodb:${region}:${CURRENT_ACCOUNT_ID}:table/${table_name}"

    # Build tags one by one
    aws dynamodb tag-resource --resource-arn "${table_arn}" --region "${region}" \
        --tags Key=ClientOrganization,Value=MMP-Toledo \
               Key=ClientAccount,Value=${MMP_TOLEDO_ACCOUNT_ID} \
               Key=ClientName,Value="Minute Man Press Toledo" \
               Key=ClientOU,Value=${MMP_TOLEDO_OU_ID} \
               Key=BillingProject,Value="$3" \
               Key=Component,Value="$4" \
               Key=Service,Value=DynamoDB \
               Key=Environment,Value="$5" \
               Key=ManagedBy,Value=terraform \
               Key=AssignedBy,Value=aws-cli \
               Key=AssignedDate,Value=${CURRENT_DATE} \
               ${6:+Key=DataClassification,Value="$6"} \
               ${7:+Key=IntegrationPartner,Value="$7"} 2>&1 || echo -e "${YELLOW}Warning: Failed to tag ${table_name}${NC}"
}

# Function to tag S3 bucket (preserving existing tags)
tag_s3_preserve() {
    local bucket_name=$1
    shift

    echo -e "${BLUE}Tagging S3 Bucket: ${bucket_name} (preserving existing tags)${NC}"

    # Get existing tags
    existing_tags=$(aws s3api get-bucket-tagging --bucket "${bucket_name}" 2>/dev/null | jq -r '.TagSet // []' || echo "[]")

    # Merge with new tags
    merged_tags=$(echo "$existing_tags" | jq --arg co "MMP-Toledo" \
        --arg ca "${MMP_TOLEDO_ACCOUNT_ID}" \
        --arg cn "Minute Man Press Toledo" \
        --arg cou "${MMP_TOLEDO_OU_ID}" \
        --arg bp "$2" \
        --arg comp "$3" \
        --arg svc "S3" \
        --arg env "$4" \
        --arg mb "terraform" \
        --arg ab "aws-cli" \
        --arg ad "${CURRENT_DATE}" \
        --arg br "$5" \
        --arg ip "$6" \
        '. + [
            {Key: "ClientOrganization", Value: $co},
            {Key: "ClientAccount", Value: $ca},
            {Key: "ClientName", Value: $cn},
            {Key: "ClientOU", Value: $cou},
            {Key: "BillingProject", Value: $bp},
            {Key: "Component", Value: $comp},
            {Key: "Service", Value: $svc},
            {Key: "Environment", Value: $env},
            {Key: "ManagedBy", Value: $mb},
            {Key: "AssignedBy", Value: $ab},
            {Key: "AssignedDate", Value: $ad}
        ] + (if $br != "" then [{Key: "Branch", Value: $br}] else [] end)
          + (if $ip != "" then [{Key: "IntegrationPartner", Value: $ip}] else [] end)
        | group_by(.Key) | map(.[0])')

    echo "$merged_tags" | jq '{TagSet: .}' > /tmp/tags-${bucket_name}.json

    aws s3api put-bucket-tagging --bucket "${bucket_name}" --tagging file:///tmp/tags-${bucket_name}.json 2>&1 || echo -e "${YELLOW}Warning: Failed to tag ${bucket_name}${NC}"
    rm -f /tmp/tags-${bucket_name}.json
}

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Fixing DynamoDB and S3 Tagging${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# MMP Toledo DynamoDB Tables
echo -e "${YELLOW}MMP Toledo DynamoDB Tables${NC}"
tag_dynamodb "mmp-toledo-leads-otp-prod" "us-east-1" "mmp-toledo" "OTPStorage" "production" "Sensitive" ""
tag_dynamodb "mmp-toledo-leads-prod" "us-east-1" "mmp-toledo" "LeadStorage" "production" "PII" ""
tag_dynamodb "mmp-toledo-otp-prod" "us-east-1" "mmp-toledo" "OTPStorage" "production" "Sensitive" ""
echo ""

# Firespring DynamoDB Tables
echo -e "${YELLOW}Firespring DynamoDB Tables${NC}"
tag_dynamodb "firespring-backdoor-actions-dev" "us-east-1" "mmp-toledo-firespring" "ActionTracking" "development" "" "Firespring"
tag_dynamodb "firespring-backdoor-extraction-jobs-dev" "us-east-1" "mmp-toledo-firespring" "JobManagement" "development" "" "Firespring"
tag_dynamodb "firespring-backdoor-network-state-dev" "us-east-1" "mmp-toledo-firespring" "NetworkState" "development" "" "Firespring"
tag_dynamodb "firespring-backdoor-searches-dev" "us-east-1" "mmp-toledo-firespring" "SearchData" "development" "" "Firespring"
tag_dynamodb "firespring-backdoor-segments-dev" "us-east-1" "mmp-toledo-firespring" "AnalyticsSegments" "development" "" "Firespring"
tag_dynamodb "firespring-backdoor-traffic-sources-dev" "us-east-1" "mmp-toledo-firespring" "TrafficSources" "development" "" "Firespring"
tag_dynamodb "firespring-backdoor-visitors-dev" "us-east-1" "mmp-toledo-firespring" "VisitorAnalytics" "development" "" "Firespring"
echo ""

# MMP Toledo S3 Buckets (with existing tag preservation)
echo -e "${YELLOW}MMP Toledo S3 Buckets${NC}"
tag_s3_preserve "mmp-toledo-shared-media" "mmp-toledo" "MediaStorage" "production" "main" ""
tag_s3_preserve "mmp-toledo-shared-media-develop" "mmp-toledo" "MediaStorage" "development" "develop" ""
echo ""

# Firespring S3 Buckets
echo -e "${YELLOW}Firespring S3 Buckets${NC}"
tag_s3_preserve "firespring-backdoor-data-30511389" "mmp-toledo-firespring" "DataStorage" "development" "" "Firespring"
tag_s3_preserve "firespring-backdoor-lambda-30511389" "mmp-toledo-firespring" "LambdaPackages" "development" "" "Firespring"
echo ""

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}DynamoDB and S3 Tagging Fixed!${NC}"
echo -e "${GREEN}================================================${NC}"
