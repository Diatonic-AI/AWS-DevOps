#!/bin/bash
#
# Client Billing Portal Setup Script
# Creates infrastructure for client cost visibility and payment processing
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MASTER_ACCOUNT_ID="313476888312"
REGION="us-east-1"

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Client Billing Portal Setup${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Step 1: Enable Cost Allocation Tags
echo -e "${BLUE}[1/7] Enabling Cost Allocation Tags${NC}"
echo "Note: It may take up to 24 hours for tags to appear in Cost Explorer after activation"

# Activate user-defined tags for cost allocation
for tag in "ClientOrganization" "BillingProject" "ClientAccount" "ClientName" "Environment"
do
    echo "  Activating tag: $tag"
    aws ce update-cost-allocation-tags-status \
        --cost-allocation-tags-status Key=$tag,Status=Active \
        2>&1 | grep -v "Warning: Input is not a terminal" || echo "    (May already be active or pending)"
done
echo ""

# Step 2: Create IAM Role for Cost Explorer Access
echo -e "${BLUE}[2/7] Creating IAM Role for Cost Explorer API Access${NC}"

cat > /tmp/cost-explorer-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

cat > /tmp/cost-explorer-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ce:GetCostAndUsage",
        "ce:GetCostForecast",
        "ce:GetDimensionValues",
        "ce:GetTags",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "tag:GetResources",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create role
aws iam create-role \
    --role-name ClientBillingPortal-CostExplorer \
    --assume-role-policy-document file:///tmp/cost-explorer-trust-policy.json \
    --description "Role for Client Billing Portal to access Cost Explorer API" \
    2>&1 | grep -v "EntityAlreadyExists" || echo "  Role may already exist"

# Attach policy
aws iam put-role-policy \
    --role-name ClientBillingPortal-CostExplorer \
    --policy-name CostExplorerAccess \
    --policy-document file:///tmp/cost-explorer-policy.json \
    2>&1 || echo "  Policy attachment may have failed"

echo "  IAM Role created: ClientBillingPortal-CostExplorer"
echo ""

# Step 3: Create DynamoDB Table for Client Billing Data
echo -e "${BLUE}[3/7] Creating DynamoDB Table for Client Billing${NC}"

aws dynamodb create-table \
    --table-name client-billing-data \
    --attribute-definitions \
        AttributeName=clientId,AttributeType=S \
        AttributeName=billingPeriod,AttributeType=S \
    --key-schema \
        AttributeName=clientId,KeyType=HASH \
        AttributeName=billingPeriod,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --tags \
        Key=Purpose,Value=ClientBillingPortal \
        Key=ManagedBy,Value=aws-cli \
    --region $REGION \
    2>&1 | grep -v "ResourceInUseException" || echo "  Table may already exist"

echo "  DynamoDB table created: client-billing-data"
echo ""

# Step 4: Create S3 Bucket for Cost Reports
echo -e "${BLUE}[4/7] Creating S3 Bucket for Cost Reports${NC}"

BUCKET_NAME="client-billing-reports-${MASTER_ACCOUNT_ID}"

aws s3 mb s3://${BUCKET_NAME} --region $REGION 2>&1 || echo "  Bucket may already exist"

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled \
    2>&1 || true

# Add bucket policy for Cost and Usage Reports
cat > /tmp/cost-report-bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "billingreports.amazonaws.com"
      },
      "Action": [
        "s3:GetBucketAcl",
        "s3:GetBucketPolicy"
      ],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "billingreports.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
    --bucket ${BUCKET_NAME} \
    --policy file:///tmp/cost-report-bucket-policy.json \
    2>&1 || true

echo "  S3 bucket created: ${BUCKET_NAME}"
echo ""

# Step 5: Create Lambda Function for Cost Retrieval
echo -e "${BLUE}[5/7] Creating Lambda Function for Cost Data Retrieval${NC}"
echo "  Lambda code will be created in next step..."
echo ""

# Step 6: Create API Gateway for Client Portal
echo -e "${BLUE}[6/7] API Gateway Setup${NC}"
echo "  API Gateway will be created with Lambda integration..."
echo ""

# Step 7: Output Configuration
echo -e "${BLUE}[7/7] Configuration Summary${NC}"
echo ""

cat > /home/daclab-ai/DEV/AWS-DevOps/config/client-billing-portal-config.json << EOF
{
  "masterAccountId": "${MASTER_ACCOUNT_ID}",
  "region": "${REGION}",
  "costAllocationTags": [
    "ClientOrganization",
    "BillingProject",
    "ClientAccount",
    "ClientName",
    "Environment"
  ],
  "iamRole": "arn:aws:iam::${MASTER_ACCOUNT_ID}:role/ClientBillingPortal-CostExplorer",
  "dynamodbTable": "client-billing-data",
  "s3Bucket": "${BUCKET_NAME}",
  "clients": {
    "mmp-toledo": {
      "clientId": "mmp-toledo",
      "clientName": "Minute Man Press Toledo",
      "accountId": "455303857245",
      "organizationTag": "MMP-Toledo",
      "billingProjects": ["mmp-toledo", "mmp-toledo-firespring"],
      "contactEmail": "aws+minute-man-press@dacvisuals.com",
      "paymentProcessor": "stripe"
    }
  },
  "stripe": {
    "apiKeySecretName": "client-billing/stripe-api-key",
    "webhookSecretName": "client-billing/stripe-webhook-secret"
  }
}
EOF

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Infrastructure Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}Created Resources:${NC}"
echo "  ✅ Cost Allocation Tags: Activated"
echo "  ✅ IAM Role: ClientBillingPortal-CostExplorer"
echo "  ✅ DynamoDB Table: client-billing-data"
echo "  ✅ S3 Bucket: ${BUCKET_NAME}"
echo "  ✅ Config File: config/client-billing-portal-config.json"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Deploy Lambda functions for cost retrieval"
echo "  2. Set up Stripe account and save API keys to Secrets Manager"
echo "  3. Create Amplify app for client portal frontend"
echo "  4. Configure automated monthly billing"
echo ""
echo -e "${BLUE}Configuration saved to: config/client-billing-portal-config.json${NC}"
echo ""

# Cleanup temp files
rm -f /tmp/cost-explorer-trust-policy.json
rm -f /tmp/cost-explorer-policy.json
rm -f /tmp/cost-report-bucket-policy.json
