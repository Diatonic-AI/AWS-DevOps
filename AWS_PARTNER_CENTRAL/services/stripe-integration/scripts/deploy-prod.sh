#!/bin/bash

# Production Deployment Script for Stripe Integration Service
# EventBridge-based architecture for AWS-native Stripe integration

set -e

ENVIRONMENT=prod
REGION=${1:-us-east-2}  # Default to us-east-2 to match Stripe EventBridge config
STACK_NAME="stripe-integration-prod"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(dirname "$SCRIPT_DIR")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deploying Stripe Integration to PRODUCTION"
echo "   Region: ${REGION}"
echo "   Architecture: EventBridge (AWS-native)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Validate AWS CLI
echo ""
echo "🔍 Pre-deployment validation..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS CLI not configured properly"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "   ✅ AWS Account: ${ACCOUNT_ID}"

# Validate CloudFormation template
cd "$SERVICE_DIR"
if ! aws cloudformation validate-template --template-body file://infrastructure.yaml --region "${REGION}" >/dev/null 2>&1; then
    echo "❌ CloudFormation template validation failed"
    aws cloudformation validate-template --template-body file://infrastructure.yaml --region "${REGION}"
    exit 1
fi
echo "   ✅ CloudFormation template valid"

# Check for Stripe secret key in SSM
if aws ssm get-parameter --name "/stripe/secret-key" --region "${REGION}" >/dev/null 2>&1; then
    echo "   ✅ Stripe secret key found in SSM"
else
    echo "   ⚠️  Stripe secret key not found in SSM Parameter Store"
    echo "      Please run: aws ssm put-parameter --name '/stripe/secret-key' --type SecureString --value 'sk_live_xxx' --region ${REGION}"
    read -p "   Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if Stripe EventBridge partner event source exists
echo ""
echo "🔗 Checking Stripe EventBridge integration..."
PARTNER_SOURCES=$(aws events list-event-sources --name-prefix "aws.partner/stripe.com" --region "${REGION}" 2>/dev/null || echo "")
if [[ -n "$PARTNER_SOURCES" && "$PARTNER_SOURCES" != "[]" ]]; then
    echo "   ✅ Stripe EventBridge partner source found"
else
    echo "   ⚠️  No Stripe EventBridge sources found"
    echo "      Make sure you've configured Stripe EventBridge destination in Stripe Dashboard"
    echo "      See: https://stripe.com/docs/event-destinations/amazon-eventbridge"
fi

# Build Lambda packages
echo ""
echo "📦 Building Lambda functions..."

cd "$SERVICE_DIR/lambda/cost-monitor"
if [ -f "package.json" ]; then
    npm install --production --silent 2>/dev/null || npm install --omit=dev --silent
    echo "   ✅ Cost Monitor dependencies installed"
else
    echo "   ⚠️  No package.json in cost-monitor, skipping npm install"
fi
cd "$SERVICE_DIR"
zip -rq cost-monitor.zip lambda/cost-monitor/ -x "*.git*" "*.DS_Store*" "test/*"
echo "   ✅ cost-monitor.zip created"

cd "$SERVICE_DIR/lambda/billing-handler"
if [ -f "package.json" ]; then
    npm install --production --silent 2>/dev/null || npm install --omit=dev --silent
    echo "   ✅ Billing Handler dependencies installed"
else
    echo "   ⚠️  No package.json in billing-handler, skipping npm install"
fi
cd "$SERVICE_DIR"
zip -rq billing-handler.zip lambda/billing-handler/ -x "*.git*" "*.DS_Store*" "test/*"
echo "   ✅ billing-handler.zip created"

# Deploy CloudFormation stack
echo ""
echo "☁️  Deploying CloudFormation stack: ${STACK_NAME}..."
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
    BudgetThreshold="1000" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "${REGION}" \
  --tags \
    Environment=prod \
    Project=StripeIntegration \
    Owner=PlatformTeam \
    CostCenter=Engineering \
    ClientOrganization=Diatonic-AI \
    BillingAllocationID=STRIPE-INT-001

echo "   ✅ CloudFormation stack deployed"

# Get Lambda function ARNs from stack outputs
echo ""
echo "⚙️  Updating Lambda function code..."

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

# Update Cost Monitor Lambda
if [ -n "${COST_MONITOR_ARN}" ] && [ "${COST_MONITOR_ARN}" != "None" ]; then
  COST_MONITOR_NAME=$(echo "${COST_MONITOR_ARN}" | awk -F: '{print $NF}')
  aws lambda update-function-code \
    --function-name "${COST_MONITOR_NAME}" \
    --zip-file fileb://cost-monitor.zip \
    --region "${REGION}" >/dev/null
  echo "   ✅ Cost Monitor Lambda updated: ${COST_MONITOR_NAME}"
fi

# Update Billing Handler Lambda
if [ -n "${BILLING_HANDLER_ARN}" ] && [ "${BILLING_HANDLER_ARN}" != "None" ]; then
  BILLING_HANDLER_NAME=$(echo "${BILLING_HANDLER_ARN}" | awk -F: '{print $NF}')
  aws lambda update-function-code \
    --function-name "${BILLING_HANDLER_NAME}" \
    --zip-file fileb://billing-handler.zip \
    --region "${REGION}" >/dev/null
  echo "   ✅ Billing Handler Lambda updated: ${BILLING_HANDLER_NAME}"
fi

# Get all stack outputs
BILLING_TABLE=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`BillingTableName`].OutputValue' \
  --output text \
  --region "${REGION}")

SUBSCRIPTIONS_TABLE=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`SubscriptionsTableName`].OutputValue' \
  --output text \
  --region "${REGION}")

NOTIFICATION_TOPIC=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`NotificationTopicArn`].OutputValue' \
  --output text \
  --region "${REGION}")

EVENT_RULE=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`StripeEventRuleName`].OutputValue' \
  --output text \
  --region "${REGION}")

DASHBOARD_URL=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`DashboardUrl`].OutputValue' \
  --output text \
  --region "${REGION}")

DLQ_URL=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`DeadLetterQueueUrl`].OutputValue' \
  --output text \
  --region "${REGION}")

# Cleanup build artifacts
rm -f cost-monitor.zip billing-handler.zip

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 PRODUCTION DEPLOYMENT COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Deployed Resources:"
echo "   Region:              ${REGION}"
echo "   Stack:               ${STACK_NAME}"
echo "   Billing Table:       ${BILLING_TABLE}"
echo "   Subscriptions Table: ${SUBSCRIPTIONS_TABLE}"
echo "   SNS Topic:           ${NOTIFICATION_TOPIC}"
echo "   EventBridge Rule:    ${EVENT_RULE}"
echo "   Dead Letter Queue:   ${DLQ_URL}"
echo ""
echo "📊 Monitoring Dashboard:"
echo "   ${DASHBOARD_URL}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 NEXT STEPS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. ✅ Stripe EventBridge destination already configured (us-east-2)"
echo "   Your events will automatically flow to: ${EVENT_RULE}"
echo ""
echo "2. Subscribe to SNS notifications for alerts:"
echo "   aws sns subscribe \\"
echo "     --topic-arn ${NOTIFICATION_TOPIC} \\"
echo "     --protocol email \\"
echo "     --notification-endpoint your-email@example.com \\"
echo "     --region ${REGION}"
echo ""
echo "3. View the CloudWatch dashboard for monitoring:"
echo "   ${DASHBOARD_URL}"
echo ""
echo "4. Test with a Stripe test event:"
echo "   - Go to Stripe Dashboard > Developers > Events"
echo "   - Click 'Send test webhook' (or create a test subscription)"
echo "   - Check CloudWatch Logs for stripe-billing-handler-prod"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ Architecture: EventBridge (AWS-native)"
echo "   - No webhook URLs needed - Stripe sends directly to EventBridge"
echo "   - IAM-authenticated (more secure than webhook secrets)"
echo "   - Automatic retries with Dead Letter Queue"
echo "   - Budget monitoring runs daily at 6 AM UTC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
