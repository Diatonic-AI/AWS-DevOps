#!/bin/bash

# Deployment script for Stripe Integration Service
# Usage: ./deploy.sh [environment] [region]

set -e

ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}
STACK_NAME="stripe-integration-${ENVIRONMENT}"

echo "Deploying Stripe Integration to ${ENVIRONMENT} environment in ${REGION}"

# Build Lambda packages
echo "Building Lambda functions..."

cd lambda/cost-monitor
npm install --production
zip -r ../../../cost-monitor.zip . -x "*.git*" "*.DS_Store*" "test/*"
cd ../..

cd lambda/billing-handler
npm install --production
zip -r ../../../billing-handler.zip . -x "*.git*" "*.DS_Store*" "test/*"
cd ../..

# Upload to S3 (optional - for larger packages)
# aws s3 cp cost-monitor.zip s3://your-bucket/lambda-packages/
# aws s3 cp billing-handler.zip s3://your-bucket/lambda-packages/

# Update CloudFormation template with actual code
# This is a simplified version - in practice, you'd use S3 references for large packages
sed -i 's|ZipFile: |# ZipFile: |g' infrastructure.yaml
sed -i 's|# This will be replaced with actual code during deployment|Code: { ZipFile: "placeholder" }|g' infrastructure.yaml

# Deploy CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file infrastructure.yaml \
  --stack-name "${STACK_NAME}" \
  --parameter-overrides \
    Environment="${ENVIRONMENT}" \
    ClientOrganization="Diatonic-AI" \
    BillingProject="global-org-tools" \
    OrganizationalUnit="ToolsAndResources" \
    BillingAllocationID="STRIPE-INT-001" \
    Owner="PlatformTeam" \
    CostCenter="Engineering" \
    Project="StripeIntegration" \
  --capabilities CAPABILITY_IAM \
  --region "${REGION}"

# Update Lambda functions with actual code
echo "Updating Lambda function code..."
COST_MONITOR_ARN=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`CostMonitorFunctionArn`].OutputValue' \
  --output text \
  --region "${REGION}")

BILLING_HANDLER_ARN=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`BillingHandlerFunctionArn`].OutputValue' \
  --output text \
  --region "${REGION}")

if [ -n "${COST_MONITOR_ARN}" ]; then
  aws lambda update-function-code \
    --function-name "${COST_MONITOR_ARN}" \
    --zip-file fileb://cost-monitor.zip \
    --region "${REGION}"
fi

if [ -n "${BILLING_HANDLER_ARN}" ]; then
  aws lambda update-function-code \
    --function-name "${BILLING_HANDLER_ARN}" \
    --zip-file fileb://billing-handler.zip \
    --region "${REGION}"
fi

# Get outputs
WEBHOOK_URL=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
  --output text \
  --region "${REGION}")

echo "Deployment complete!"
echo "Stripe Webhook URL: ${WEBHOOK_URL}/webhook"
echo ""
echo "Next steps:"
echo "1. Configure Stripe webhook endpoint in Stripe Dashboard"
echo "2. Subscribe email addresses to SNS topic for notifications"
echo "3. Test the integration"

# Cleanup
rm -f cost-monitor.zip billing-handler.zip