#!/bin/bash
set -euo pipefail

# Deploy Partner Central Integration
# This script deploys Lambda functions and EventBridge schedules to sync
# Partner Central opportunities with the client billing portal

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                              ║${NC}"
echo -e "${BLUE}║   Partner Central Integration Deployment                    ║${NC}"
echo -e "${BLUE}║                                                              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TABLE_NAME="client-billing-data"
LAMBDA_ROLE_NAME="ClientBillingLambdaRole"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Account ID: $ACCOUNT_ID"
echo "  Region: $REGION"
echo "  DynamoDB Table: $TABLE_NAME"
echo "  Lambda Role: $LAMBDA_ROLE_NAME"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 1: Verify Prerequisites
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}Step 1: Verifying Prerequisites${NC}"

# Check if DynamoDB table exists
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" &>/dev/null; then
    echo -e "${GREEN}✓ DynamoDB table exists: $TABLE_NAME${NC}"
else
    echo -e "${RED}✗ DynamoDB table not found: $TABLE_NAME${NC}"
    echo "  Run: ./scripts/setup-client-billing-portal.sh"
    exit 1
fi

# Check if IAM role exists
if aws iam get-role --role-name "$LAMBDA_ROLE_NAME" &>/dev/null; then
    echo -e "${GREEN}✓ IAM role exists: $LAMBDA_ROLE_NAME${NC}"
else
    echo -e "${YELLOW}⚠ IAM role not found. Creating...${NC}"

    # Create trust policy
    cat > /tmp/lambda-trust-policy.json <<EOF
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

    # Create role
    aws iam create-role \
        --role-name "$LAMBDA_ROLE_NAME" \
        --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
        --region "$REGION"

    # Attach policies
    aws iam attach-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" \
        --region "$REGION"

    # Create inline policy for DynamoDB and Partner Central
    cat > /tmp/lambda-inline-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/$TABLE_NAME"
    },
    {
      "Effect": "Allow",
      "Action": [
        "partnercentral-selling:ListOpportunities",
        "partnercentral-selling:GetOpportunity",
        "partnercentral-selling:ListEngagementInvitations",
        "partnercentral-selling:GetEngagementInvitation"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:$REGION:$ACCOUNT_ID:secret:client-billing/*"
    }
  ]
}
EOF

    aws iam put-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-name "PartnerCentralBillingAccess" \
        --policy-document file:///tmp/lambda-inline-policy.json \
        --region "$REGION"

    echo -e "${GREEN}✓ IAM role created${NC}"

    # Wait for role to propagate
    echo "  Waiting 10 seconds for IAM role to propagate..."
    sleep 10
fi

echo ""

# ═══════════════════════════════════════════════════════════
# Step 2: Package Lambda Function
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}Step 2: Packaging Lambda Function${NC}"

LAMBDA_DIR="lambda/partner-central-sync"
ZIP_FILE="partner-central-sync.zip"

cd "$LAMBDA_DIR"

# Install dependencies
if [ ! -d "node_modules" ]; then
    echo "  Installing Node.js dependencies..."
    npm install --production
fi

# Create deployment package
echo "  Creating deployment package..."
zip -r "../../$ZIP_FILE" . -x "*.git*" -x "node_modules/@aws-sdk/client-s3/*" > /dev/null

cd ../..

echo -e "${GREEN}✓ Lambda package created: $ZIP_FILE${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 3: Deploy Lambda Function
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}Step 3: Deploying Lambda Function${NC}"

FUNCTION_NAME="partner-central-sync"
LAMBDA_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$LAMBDA_ROLE_NAME"

# Check if function exists
if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" &>/dev/null; then
    echo "  Updating existing function..."

    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://$ZIP_FILE" \
        --region "$REGION" > /dev/null

    aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --runtime nodejs18.x \
        --timeout 300 \
        --memory-size 512 \
        --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
        --region "$REGION" > /dev/null

    echo -e "${GREEN}✓ Lambda function updated${NC}"
else
    echo "  Creating new function..."

    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime nodejs18.x \
        --role "$LAMBDA_ROLE_ARN" \
        --handler index.handler \
        --zip-file "fileb://$ZIP_FILE" \
        --timeout 300 \
        --memory-size 512 \
        --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
        --description "Sync AWS Partner Central opportunities and referrals to DynamoDB" \
        --region "$REGION" > /dev/null

    echo -e "${GREEN}✓ Lambda function created${NC}"
fi

# Clean up zip file
rm "$ZIP_FILE"

echo ""

# ═══════════════════════════════════════════════════════════
# Step 4: Create EventBridge Schedule
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}Step 4: Creating EventBridge Schedule${NC}"

RULE_NAME="partner-central-sync-schedule"
LAMBDA_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$FUNCTION_NAME"

# Create/Update EventBridge rule
aws events put-rule \
    --name "$RULE_NAME" \
    --schedule-expression "rate(6 hours)" \
    --state ENABLED \
    --description "Sync Partner Central opportunities every 6 hours" \
    --region "$REGION" > /dev/null

echo -e "${GREEN}✓ EventBridge rule created: $RULE_NAME${NC}"

# Add Lambda permission for EventBridge
aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id AllowEventBridgeInvoke \
    --action lambda:InvokeFunction \
    --principal events.amazonaws.com \
    --source-arn "arn:aws:events:$REGION:$ACCOUNT_ID:rule/$RULE_NAME" \
    --region "$REGION" 2>/dev/null || echo "  Permission already exists"

# Add Lambda as target
aws events put-targets \
    --rule "$RULE_NAME" \
    --targets "Id"="1","Arn"="$LAMBDA_ARN" \
    --region "$REGION" > /dev/null

echo -e "${GREEN}✓ Lambda configured as EventBridge target${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 5: Test Deployment
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}Step 5: Testing Deployment${NC}"

echo "  Invoking Lambda function for initial sync..."

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    /tmp/partner-central-sync-output.json > /dev/null

if [ -f /tmp/partner-central-sync-output.json ]; then
    echo ""
    echo -e "${YELLOW}Lambda Response:${NC}"
    cat /tmp/partner-central-sync-output.json | jq '.'
    echo ""
fi

# ═══════════════════════════════════════════════════════════
# Deployment Summary
# ═══════════════════════════════════════════════════════════

echo -e "${GREEN}"
cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   ✓ Partner Central Integration Deployed Successfully       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${YELLOW}Deployment Summary:${NC}"
echo "  ✓ Lambda Function: $FUNCTION_NAME"
echo "  ✓ EventBridge Rule: $RULE_NAME (runs every 6 hours)"
echo "  ✓ DynamoDB Table: $TABLE_NAME"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. View Lambda logs:"
echo "   aws logs tail /aws/lambda/$FUNCTION_NAME --follow --region $REGION"
echo ""
echo "2. Check synced clients in DynamoDB:"
echo "   aws dynamodb scan --table-name $TABLE_NAME \\"
echo "     --filter-expression 'begins_with(PK, :prefix)' \\"
echo "     --expression-attribute-values '{\":prefix\":{\"S\":\"CLIENT#\"}}' \\"
echo "     --region $REGION"
echo ""
echo "3. Manually trigger sync:"
echo "   aws lambda invoke \\"
echo "     --function-name $FUNCTION_NAME \\"
echo "     --region $REGION \\"
echo "     /tmp/output.json"
echo ""
echo "4. View EventBridge rule:"
echo "   aws events describe-rule --name $RULE_NAME --region $REGION"
echo ""

echo -e "${YELLOW}Monitoring:${NC}"
echo "  • CloudWatch Logs: /aws/lambda/$FUNCTION_NAME"
echo "  • EventBridge Rule: $RULE_NAME"
echo "  • DynamoDB Table: $TABLE_NAME"
echo ""

echo -e "${GREEN}Done!${NC}"
