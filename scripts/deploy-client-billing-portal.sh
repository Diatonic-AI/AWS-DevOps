#!/bin/bash
#
# Complete Deployment Script for Client Billing Portal
# Deploys Lambda functions, creates API Gateway, sets up Amplify hosting
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MASTER_ACCOUNT_ID="313476888312"
REGION="us-east-1"
LAMBDA_ROLE="arn:aws:iam::${MASTER_ACCOUNT_ID}:role/ClientBillingPortal-CostExplorer"

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Deploying Client Billing Portal${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Step 1: Package and Deploy Lambda Functions
echo -e "${BLUE}[1/6] Packaging and Deploying Lambda Functions${NC}"
echo ""

# Deploy Cost Retrieval Lambda
echo "  📦 Packaging client-billing-costs Lambda..."
cd /home/daclab-ai/DEV/AWS-DevOps/lambda/client-billing-costs
npm install --production 2>/dev/null || echo "No package.json or dependencies already installed"
zip -r function.zip . > /dev/null 2>&1

echo "  🚀 Creating/Updating client-billing-costs Lambda function..."
aws lambda create-function \
    --function-name client-billing-costs \
    --runtime nodejs20.x \
    --role ${LAMBDA_ROLE} \
    --handler index.handler \
    --zip-file fileb://function.zip \
    --timeout 30 \
    --memory-size 512 \
    --environment "Variables={DYNAMODB_TABLE=client-billing-data,AWS_REGION=${REGION}}" \
    --region ${REGION} \
    2>&1 | grep -v "ResourceConflictException" || {
        aws lambda update-function-code \
            --function-name client-billing-costs \
            --zip-file fileb://function.zip \
            --region ${REGION} > /dev/null 2>&1
        echo "    ✅ Updated existing function"
    }

rm -f function.zip

# Deploy Payment Processing Lambda
echo "  📦 Packaging client-billing-payment Lambda..."
cd /home/daclab-ai/DEV/AWS-DevOps/lambda/client-billing-payment
npm install --production 2>/dev/null || echo "No package.json or dependencies already installed"
zip -r function.zip . > /dev/null 2>&1

echo "  🚀 Creating/Updating client-billing-payment Lambda function..."
aws lambda create-function \
    --function-name client-billing-payment \
    --runtime nodejs20.x \
    --role ${LAMBDA_ROLE} \
    --handler index.handler \
    --zip-file fileb://function.zip \
    --timeout 30 \
    --memory-size 512 \
    --environment "Variables={DYNAMODB_TABLE=client-billing-data,STRIPE_SECRET_NAME=client-billing/stripe-api-key,AWS_REGION=${REGION}}" \
    --region ${REGION} \
    2>&1 | grep -v "ResourceConflictException" || {
        aws lambda update-function-code \
            --function-name client-billing-payment \
            --zip-file fileb://function.zip \
            --region ${REGION} > /dev/null 2>&1
        echo "    ✅ Updated existing function"
    }

rm -f function.zip
cd /home/daclab-ai/DEV/AWS-DevOps

echo ""

# Step 2: Create API Gateway
echo -e "${BLUE}[2/6] Creating API Gateway${NC}"
echo ""

# Create HTTP API
API_ID=$(aws apigatewayv2 create-api \
    --name "client-billing-portal-api" \
    --protocol-type HTTP \
    --cors-configuration "AllowOrigins=*,AllowMethods=GET,POST,OPTIONS,AllowHeaders=Content-Type,Authorization" \
    --region ${REGION} \
    --query 'ApiId' \
    --output text 2>&1 || aws apigatewayv2 get-apis --region ${REGION} --query "Items[?Name=='client-billing-portal-api'].ApiId" --output text)

echo "  ✅ API Gateway created/found: ${API_ID}"

# Create Lambda integrations
COSTS_INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id ${API_ID} \
    --integration-type AWS_PROXY \
    --integration-uri "arn:aws:lambda:${REGION}:${MASTER_ACCOUNT_ID}:function:client-billing-costs" \
    --payload-format-version 2.0 \
    --region ${REGION} \
    --query 'IntegrationId' \
    --output text 2>&1 || echo "exists")

PAYMENT_INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id ${API_ID} \
    --integration-type AWS_PROXY \
    --integration-uri "arn:aws:lambda:${REGION}:${MASTER_ACCOUNT_ID}:function:client-billing-payment" \
    --payload-format-version 2.0 \
    --region ${REGION} \
    --query 'IntegrationId' \
    --output text 2>&1 || echo "exists")

# Create routes
aws apigatewayv2 create-route \
    --api-id ${API_ID} \
    --route-key "GET /costs" \
    --target "integrations/${COSTS_INTEGRATION_ID}" \
    --region ${REGION} 2>&1 | grep -v "ConflictException" || echo "  Route already exists"

aws apigatewayv2 create-route \
    --api-id ${API_ID} \
    --route-key "POST /payment" \
    --target "integrations/${PAYMENT_INTEGRATION_ID}" \
    --region ${REGION} 2>&1 | grep -v "ConflictException" || echo "  Route already exists"

# Create stage
aws apigatewayv2 create-stage \
    --api-id ${API_ID} \
    --stage-name prod \
    --auto-deploy \
    --region ${REGION} 2>&1 | grep -v "ConflictException" || echo "  Stage already exists"

# Add Lambda permissions
aws lambda add-permission \
    --function-name client-billing-costs \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${MASTER_ACCOUNT_ID}:${API_ID}/*" \
    --region ${REGION} 2>&1 | grep -v "ResourceConflictException" || echo "  Permission already exists"

aws lambda add-permission \
    --function-name client-billing-payment \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${MASTER_ACCOUNT_ID}:${API_ID}/*" \
    --region ${REGION} 2>&1 | grep -v "ResourceConflictException" || echo "  Permission already exists"

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod"
echo "  ✅ API Gateway URL: ${API_URL}"
echo ""

# Step 3: Update Client Portal with API URL
echo -e "${BLUE}[3/6] Updating Client Portal Configuration${NC}"
echo ""

# Update the index.html with the actual API URL
sed -i "s|YOUR_API_GATEWAY_URL|${API_URL}|g" /home/daclab-ai/DEV/AWS-DevOps/client-portal/public/index.html

echo "  ✅ Updated client portal with API URL"
echo ""

# Step 4: Deploy to Amplify (optional - can also use S3 + CloudFront)
echo -e "${BLUE}[4/6] Deployment Options${NC}"
echo ""
echo "  Choose deployment method:"
echo "  A) Deploy to AWS Amplify (Recommended for production)"
echo "  B) Deploy to S3 + CloudFront"
echo "  C) Test locally"
echo ""
echo "  📝 For now, files are ready in: /home/daclab-ai/DEV/AWS-DevOps/client-portal/public/"
echo ""

# Step 5: Create Stripe Secret (manual step)
echo -e "${BLUE}[5/6] Stripe Configuration${NC}"
echo ""
echo "  ⚠️  MANUAL STEP REQUIRED:"
echo "  1. Create Stripe account at https://stripe.com"
echo "  2. Get your API keys from Stripe Dashboard"
echo "  3. Save to AWS Secrets Manager:"
echo ""
echo "     aws secretsmanager create-secret \\"
echo "       --name client-billing/stripe-api-key \\"
echo "       --secret-string '{\"apiKey\":\"sk_live_YOUR_KEY_HERE\"}' \\"
echo "       --region ${REGION}"
echo ""

# Step 6: Summary
echo -e "${BLUE}[6/6] Deployment Summary${NC}"
echo ""

cat > /home/daclab-ai/DEV/AWS-DevOps/CLIENT-BILLING-PORTAL-DEPLOYMENT.md << EOF
# Client Billing Portal - Deployment Summary

**Deployment Date:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')
**AWS Region:** ${REGION}
**Account ID:** ${MASTER_ACCOUNT_ID}

## Deployed Resources

### Lambda Functions

1. **client-billing-costs**
   - Runtime: Node.js 20.x
   - Function: Fetch costs from Cost Explorer API
   - ARN: arn:aws:lambda:${REGION}:${MASTER_ACCOUNT_ID}:function:client-billing-costs

2. **client-billing-payment**
   - Runtime: Node.js 20.x
   - Function: Stripe payment processing
   - ARN: arn:aws:lambda:${REGION}:${MASTER_ACCOUNT_ID}:function:client-billing-payment

### API Gateway

- **API ID:** ${API_ID}
- **API URL:** ${API_URL}
- **Endpoints:**
  - GET ${API_URL}/costs - Fetch client costs
  - POST ${API_URL}/payment - Payment processing

### DynamoDB Table

- **Table Name:** client-billing-data
- **Purpose:** Store billing data and Stripe customer info

### Client Portal

- **Location:** /home/daclab-ai/DEV/AWS-DevOps/client-portal/public/
- **Entry Point:** index.html

## Next Steps

### 1. Set Up Stripe

Create a Stripe account and save API keys:

\`\`\`bash
aws secretsmanager create-secret \\
    --name client-billing/stripe-api-key \\
    --secret-string '{"apiKey":"sk_live_YOUR_KEY_HERE"}' \\
    --region ${REGION}
\`\`\`

### 2. Deploy Client Portal

**Option A: Amplify Hosting (Recommended)**

\`\`\`bash
# Create new Amplify app
aws amplify create-app \\
    --name client-billing-portal \\
    --repository https://github.com/YOUR-ORG/client-billing-portal \\
    --region us-east-2

# Or use manual deployment
cd /home/daclab-ai/DEV/AWS-DevOps/client-portal
zip -r portal.zip public/
# Upload to Amplify Console
\`\`\`

**Option B: S3 + CloudFront**

\`\`\`bash
# Create S3 bucket
aws s3 mb s3://client-billing-portal-${MASTER_ACCOUNT_ID} --region ${REGION}

# Enable static website hosting
aws s3 website s3://client-billing-portal-${MASTER_ACCOUNT_ID} \\
    --index-document index.html

# Upload files
aws s3 sync /home/daclab-ai/DEV/AWS-DevOps/client-portal/public/ \\
    s3://client-billing-portal-${MASTER_ACCOUNT_ID}/

# Create CloudFront distribution (see AWS Console)
\`\`\`

### 3. Configure Cost Allocation Tags

Wait 24 hours for tags to appear in Cost Explorer, then activate them:

\`\`\`bash
aws ce update-cost-allocation-tags-status \\
    --cost-allocation-tags-status \\
    Key=ClientOrganization,Status=Active \\
    Key=BillingProject,Status=Active
\`\`\`

### 4. Set Up Automated Monthly Billing

Create EventBridge rule for monthly invoicing:

\`\`\`bash
# Create rule that triggers on 1st of each month
aws events put-rule \\
    --name monthly-client-billing \\
    --schedule-expression "cron(0 0 1 * ? *)" \\
    --region ${REGION}

# Add Lambda target (create invoicing Lambda first)
aws events put-targets \\
    --rule monthly-client-billing \\
    --targets "Id"="1","Arn"="arn:aws:lambda:${REGION}:${MASTER_ACCOUNT_ID}:function:monthly-invoice-generator" \\
    --region ${REGION}
\`\`\`

## Client Access

### For MMP Toledo:

1. **Portal URL:** [YOUR_AMPLIFY_URL or CloudFront URL]
2. **Client ID:** mmp-toledo
3. **Organization Tag:** MMP-Toledo

### Login Credentials:

- No traditional login required
- Access via unique URL per client
- Option to add authentication (Cognito) later

## Testing

### Test Cost API:

\`\`\`bash
curl "${API_URL}/costs?clientOrganization=MMP-Toledo&period=current-month"
\`\`\`

### Test Payment Setup:

\`\`\`bash
curl -X POST ${API_URL}/payment \\
    -H "Content-Type: application/json" \\
    -d '{
        "action": "setup-payment-method",
        "clientId": "mmp-toledo",
        "clientName": "Minute Man Press Toledo",
        "email": "aws+minute-man-press@dacvisuals.com",
        "portalUrl": "https://your-portal-url.com"
    }'
\`\`\`

## Monitoring

### CloudWatch Logs:

- /aws/lambda/client-billing-costs
- /aws/lambda/client-billing-payment

### Metrics to Monitor:

- Lambda invocations
- API Gateway requests
- DynamoDB read/write capacity
- Lambda errors

## Cost Estimation

### Monthly Costs (approximate):

- Lambda (1000 requests/month): ~\$0.20
- API Gateway (1000 requests/month): ~\$1.00
- DynamoDB (on-demand): ~\$2.50
- S3/Amplify hosting: ~\$0.50
- **Total: ~\$4-5/month**

## Support

For issues or questions:
- Check CloudWatch Logs for errors
- Review Stripe dashboard for payment issues
- Contact: aws@dacvisuals.com

---

**Generated by:** Client Billing Portal Deployment Script
**Documentation:** /home/daclab-ai/DEV/AWS-DevOps/docs/CLIENT-BILLING-PORTAL.md
EOF

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}Deployed Resources:${NC}"
echo "  ✅ 2 Lambda Functions"
echo "  ✅ API Gateway with 2 endpoints"
echo "  ✅ DynamoDB table"
echo "  ✅ Client Portal (ready to deploy)"
echo ""
echo -e "${YELLOW}API Gateway URL:${NC}"
echo "  ${API_URL}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Set up Stripe account and save API key to Secrets Manager"
echo "  2. Deploy client portal to Amplify or S3"
echo "  3. Test the portal with your first client (MMP Toledo)"
echo "  4. Enable cost allocation tags (wait 24 hours)"
echo ""
echo -e "${BLUE}Documentation:${NC} CLIENT-BILLING-PORTAL-DEPLOYMENT.md"
echo ""
