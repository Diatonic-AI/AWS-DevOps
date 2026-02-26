#!/bin/bash
#
# Create AWS Resource Groups for MMP Toledo Resources
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Creating AWS Resource Groups for MMP Toledo${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Create MMP Toledo Core Resources Group
echo -e "${BLUE}[1/4] Creating MMP Toledo Core Resources Group${NC}"
aws resource-groups create-group \
    --name "MMP-Toledo-Core-Resources" \
    --description "All core MMP Toledo lead generation resources (Amplify, Lambda, DynamoDB, API Gateway, S3)" \
    --resource-query '{
        "Type": "TAG_FILTERS_1_0",
        "Query": "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"ClientOrganization\",\"Values\":[\"MMP-Toledo\"]},{\"Key\":\"BillingProject\",\"Values\":[\"mmp-toledo\"]}]}"
    }' \
    --tags "ClientOrganization=MMP-Toledo,ManagedBy=aws-cli,Purpose=ResourceManagement,CreatedDate=$(date -u +%Y-%m-%d)" \
    --region us-east-1 2>&1 || echo -e "${YELLOW}Group may already exist${NC}"
echo ""

# Create Firespring Integration Resources Group
echo -e "${BLUE}[2/4] Creating Firespring Integration Resources Group${NC}"
aws resource-groups create-group \
    --name "MMP-Toledo-Firespring-Integration" \
    --description "Firespring data extraction pipeline resources for MMP Toledo" \
    --resource-query '{
        "Type": "TAG_FILTERS_1_0",
        "Query": "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"ClientOrganization\",\"Values\":[\"MMP-Toledo\"]},{\"Key\":\"BillingProject\",\"Values\":[\"mmp-toledo-firespring\"]}]}"
    }' \
    --tags "ClientOrganization=MMP-Toledo,ManagedBy=aws-cli,Purpose=ResourceManagement,IntegrationPartner=Firespring,CreatedDate=$(date -u +%Y-%m-%d)" \
    --region us-east-1 2>&1 || echo -e "${YELLOW}Group may already exist${NC}"
echo ""

# Create All MMP Toledo Resources Group (combined)
echo -e "${BLUE}[3/4] Creating All MMP Toledo Resources Group (Combined)${NC}"
aws resource-groups create-group \
    --name "MMP-Toledo-All-Resources" \
    --description "All MMP Toledo resources including core platform and integrations" \
    --resource-query '{
        "Type": "TAG_FILTERS_1_0",
        "Query": "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"ClientOrganization\",\"Values\":[\"MMP-Toledo\"]}]}"
    }' \
    --tags "ClientOrganization=MMP-Toledo,ClientAccount=455303857245,ManagedBy=aws-cli,Purpose=ResourceManagement,Scope=All,CreatedDate=$(date -u +%Y-%m-%d)" \
    --region us-east-1 2>&1 || echo -e "${YELLOW}Group may already exist${NC}"
echo ""

# Create Production Resources Group
echo -e "${BLUE}[4/4] Creating MMP Toledo Production Resources Group${NC}"
aws resource-groups create-group \
    --name "MMP-Toledo-Production-Resources" \
    --description "Production environment resources for MMP Toledo" \
    --resource-query '{
        "Type": "TAG_FILTERS_1_0",
        "Query": "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"ClientOrganization\",\"Values\":[\"MMP-Toledo\"]},{\"Key\":\"Environment\",\"Values\":[\"production\",\"prod\"]}]}"
    }' \
    --tags "ClientOrganization=MMP-Toledo,Environment=production,ManagedBy=aws-cli,Purpose=ResourceManagement,CreatedDate=$(date -u +%Y-%m-%d)" \
    --region us-east-1 2>&1 || echo -e "${YELLOW}Group may already exist${NC}"
echo ""

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Resource Groups Created!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Created Resource Groups:${NC}"
echo -e "  1. MMP-Toledo-Core-Resources - Core platform resources"
echo -e "  2. MMP-Toledo-Firespring-Integration - Firespring integration"
echo -e "  3. MMP-Toledo-All-Resources - All MMP Toledo resources"
echo -e "  4. MMP-Toledo-Production-Resources - Production resources only"
echo ""
echo -e "${YELLOW}Viewing Resource Groups:${NC}"
echo -e "  AWS Console: https://console.aws.amazon.com/resource-groups"
echo -e "  CLI: aws resource-groups list-groups --region us-east-1"
echo ""
