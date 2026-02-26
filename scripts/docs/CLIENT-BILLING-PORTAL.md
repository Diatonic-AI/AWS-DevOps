# Client Billing Portal - Complete Guide

## Overview

The Client Billing Portal is a simple, user-friendly web application that allows your clients to:

- 📊 **View real-time AWS costs** broken down by service and project
- 💰 **See usage dashboards** with daily cost charts and forecasts
- 💳 **Add payment methods** securely through Stripe
- 🔄 **Automatic monthly billing** without manual intervention
- 📧 **Email invoice delivery** with payment links

## For Tech-Illiterate Clients

This portal is designed to be **extremely simple**:

1. **No complex dashboards** - Just show costs, charts, and a payment button
2. **One-click payment setup** - Clients click "Add Payment Method" and enter their card
3. **Automatic billing** - Monthly invoices are automatically created and charged
4. **Email notifications** - Clients receive invoices via email with payment links

## Architecture

```
Client Browser
    ↓
Client Portal (Amplify/S3)
    ↓
API Gateway
    ↓
┌─────────────────┬──────────────────┐
│                 │                  │
Lambda:           Lambda:            DynamoDB
Cost Retrieval    Payment Processing  (Billing Data)
    ↓                   ↓
Cost Explorer     Stripe API
```

## Components

### 1. Client Portal (Frontend)

**Location:** `/home/daclab-ai/DEV/AWS-DevOps/client-portal/public/index.html`

**Features:**
- Responsive design for mobile and desktop
- Real-time cost data display
- Interactive Chart.js charts
- Stripe payment integration
- No authentication required (access via unique URL per client)

**Customization:**
- Update `CLIENT_ORG`, `CLIENT_ID`, `CLIENT_NAME` in index.html for each client
- Change colors/branding in CSS
- Add logo by modifying header section

### 2. Lambda Functions

#### client-billing-costs

**Purpose:** Fetch cost data from AWS Cost Explorer API

**Endpoints:**
- `GET /costs?clientOrganization=MMP-Toledo&period=current-month`
- Query parameters:
  - `clientOrganization` (required): Tag value to filter costs
  - `period`: `current-month`, `last-month`, `last-30-days`, or custom dates

**Response:**
```json
{
  "clientOrganization": "MMP-Toledo",
  "period": { "start": "2025-12-01", "end": "2025-12-24", "type": "current-month" },
  "summary": {
    "totalCost": 125.50,
    "byService": {
      "AWS Lambda": { "cost": 45.20, "usage": 1000000 },
      "Amazon DynamoDB": { "cost": 30.15, "usage": 500000 },
      ...
    },
    "byProject": {
      "mmp-toledo": { "cost": 85.30, "usage": 1200000 },
      "mmp-toledo-firespring": { "cost": 40.20, "usage": 300000 }
    },
    "dailyBreakdown": [
      { "date": "2025-12-01", "cost": 4.50 },
      ...
    ]
  },
  "forecast": {
    "amount": 180.00,
    "unit": "USD",
    "period": "next-30-days"
  }
}
```

#### client-billing-payment

**Purpose:** Handle Stripe payment method setup and invoicing

**Actions:**

1. **Setup Payment Method**
   ```json
   POST /payment
   {
     "action": "setup-payment-method",
     "clientId": "mmp-toledo",
     "clientName": "Minute Man Press Toledo",
     "email": "client@example.com",
     "portalUrl": "https://portal.example.com"
   }
   ```
   Returns: `{ "sessionId": "...", "url": "https://checkout.stripe.com/..." }`

2. **Create Invoice**
   ```json
   POST /payment
   {
     "action": "create-invoice",
     "clientId": "mmp-toledo",
     "clientName": "Minute Man Press Toledo",
     "email": "client@example.com",
     "billingPeriod": "2025-12",
     "amount": 125.50
   }
   ```
   Returns: `{ "invoiceId": "...", "invoiceUrl": "...", "amount": 125.50 }`

3. **Get Payment Methods**
   ```json
   POST /payment
   {
     "action": "get-payment-methods",
     "clientId": "mmp-toledo",
     "clientName": "Minute Man Press Toledo",
     "email": "client@example.com"
   }
   ```
   Returns: `{ "paymentMethods": [...] }`

4. **Customer Portal**
   ```json
   POST /payment
   {
     "action": "customer-portal",
     "clientId": "mmp-toledo",
     "clientName": "Minute Man Press Toledo",
     "email": "client@example.com",
     "returnUrl": "https://portal.example.com"
   }
   ```
   Returns: `{ "url": "https://billing.stripe.com/..." }`

### 3. DynamoDB Table

**Table Name:** `client-billing-data`

**Schema:**
- Partition Key: `clientId` (String)
- Sort Key: `billingPeriod` (String)

**Data Types:**

1. **Cost Data:**
   ```json
   {
     "clientId": "mmp-toledo",
     "billingPeriod": "2025-12-01_2025-12-31",
     "costData": { ... },
     "generatedAt": "2025-12-24T12:00:00Z",
     "ttl": 1735689600
   }
   ```

2. **Stripe Customer:**
   ```json
   {
     "clientId": "mmp-toledo",
     "billingPeriod": "stripe-customer",
     "stripeCustomerId": "cus_...",
     "createdAt": "2025-12-24T12:00:00Z"
   }
   ```

3. **Invoice Record:**
   ```json
   {
     "clientId": "mmp-toledo",
     "billingPeriod": "invoice-2025-12",
     "stripeInvoiceId": "in_...",
     "amount": 125.50,
     "status": "paid",
     "createdAt": "2025-12-31T12:00:00Z"
   }
   ```

## Deployment

### Step 1: Set Up Stripe

1. Create account at https://stripe.com
2. Get API keys from Dashboard → Developers → API keys
3. Save to AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
    --name client-billing/stripe-api-key \
    --secret-string '{"apiKey":"sk_live_YOUR_SECRET_KEY_HERE"}' \
    --region us-east-1
```

### Step 2: Run Infrastructure Setup

```bash
chmod +x /home/daclab-ai/DEV/AWS-DevOps/scripts/setup-client-billing-portal.sh
./scripts/setup-client-billing-portal.sh
```

This creates:
- IAM role for Lambda functions
- DynamoDB table for billing data
- S3 bucket for cost reports
- Configuration file

### Step 3: Deploy Lambda Functions and API Gateway

```bash
chmod +x /home/daclab-ai/DEV/AWS-DevOps/scripts/deploy-client-billing-portal.sh
./scripts/deploy-client-billing-portal.sh
```

This:
- Packages and deploys Lambda functions
- Creates API Gateway with routes
- Updates client portal with API URL
- Generates deployment documentation

### Step 4: Deploy Client Portal

**Option A: AWS Amplify (Recommended)**

1. Create GitHub repository for client portal
2. Push files from `/home/daclab-ai/DEV/AWS-DevOps/client-portal/`
3. In AWS Amplify Console:
   - Create new app
   - Connect to GitHub repository
   - Set build settings (already configured)
   - Deploy

**Option B: S3 + CloudFront**

```bash
# Create S3 bucket
aws s3 mb s3://client-billing-portal-313476888312 --region us-east-1

# Enable static website hosting
aws s3 website s3://client-billing-portal-313476888312 \
    --index-document index.html

# Upload files
aws s3 sync /home/daclab-ai/DEV/AWS-DevOps/client-portal/public/ \
    s3://client-billing-portal-313476888312/ \
    --acl public-read

# Access at: http://client-billing-portal-313476888312.s3-website-us-east-1.amazonaws.com
```

For production, add CloudFront distribution for HTTPS and custom domain.

## Client Onboarding Workflow

### For MMP Toledo (Example):

1. **Create client-specific portal:**
   - Copy `index.html`
   - Update constants:
     ```javascript
     const CLIENT_ORG = 'MMP-Toledo';
     const CLIENT_ID = 'mmp-toledo';
     const CLIENT_NAME = 'Minute Man Press Toledo';
     const CLIENT_EMAIL = 'aws+minute-man-press@dacvisuals.com';
     ```
   - Deploy to unique URL (e.g., `mmp-toledo.billing.dacvisuals.com`)

2. **Send welcome email:**
   ```
   Subject: Welcome to Your AWS Billing Portal

   Dear Minute Man Press Toledo,

   Your AWS billing portal is now ready! You can:
   - View your AWS usage and costs in real-time
   - Set up automatic monthly billing
   - Manage your payment methods

   Access your portal: https://mmp-toledo.billing.dacvisuals.com

   Getting Started:
   1. Click "Add Payment Method" to securely enter your credit card
   2. Review your current AWS costs and usage
   3. We'll automatically bill you monthly

   Questions? Reply to this email or contact aws@dacvisuals.com

   Best regards,
   DAC Visuals Team
   ```

3. **Client accesses portal:**
   - Sees current costs immediately
   - Clicks "Add Payment Method"
   - Redirected to Stripe Checkout (PCI-compliant, secure)
   - Enters credit card information
   - Redirected back with success message

4. **Automated monthly billing:**
   - EventBridge triggers Lambda on 1st of each month
   - Lambda fetches costs for previous month
   - Creates Stripe invoice
   - Charges customer's card automatically
   - Sends email with receipt

## Cost Allocation Tags

Required tags for cost tracking (already applied):

- `ClientOrganization` - e.g., "MMP-Toledo"
- `BillingProject` - e.g., "mmp-toledo" or "mmp-toledo-firespring"
- `ClientAccount` - AWS account ID of client
- `ClientName` - Human-readable name

**Activation:** Takes up to 24 hours after tags are created. Status can be checked in AWS Cost Explorer console.

## Automated Monthly Billing

### Create Invoicing Lambda

```javascript
// lambda/monthly-invoice-generator/index.js
exports.handler = async (event) => {
    const clients = ['mmp-toledo', 'other-client-id'];

    for (const clientId of clients) {
        // Fetch last month's costs
        const costs = await getCostsForLastMonth(clientId);

        // Create Stripe invoice
        await createInvoice(clientId, costs.total);

        // Send email notification
        await sendInvoiceEmail(clientId, costs.total);
    }
};
```

### Schedule with EventBridge

```bash
# Create rule for 1st of each month at midnight
aws events put-rule \
    --name monthly-client-billing \
    --schedule-expression "cron(0 0 1 * ? *)" \
    --region us-east-1

# Add Lambda target
aws events put-targets \
    --rule monthly-client-billing \
    --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:313476888312:function:monthly-invoice-generator" \
    --region us-east-1
```

## Security

### Payment Security

- **No card data touches your servers** - All payment info goes directly to Stripe
- **PCI-DSS compliant** - Stripe handles all PCI compliance
- **Tokenization** - Cards are tokenized and stored securely by Stripe
- **3D Secure** - Optional support for extra authentication

### API Security

**Current:** Open API (no authentication)
- Suitable for initial deployment
- Costs are not sensitive (just totals)
- Client-specific URLs provide security through obscurity

**Recommended for Production:**

Add API Gateway authorization:

```bash
# Create Cognito User Pool
aws cognito-idp create-user-pool \
    --pool-name client-billing-users \
    --region us-east-1

# Add authorizer to API Gateway
aws apigatewayv2 create-authorizer \
    --api-id YOUR_API_ID \
    --authorizer-type JWT \
    --identity-source '$request.header.Authorization' \
    --jwt-configuration Audience=YOUR_CLIENT_ID,Issuer=https://cognito-idp.us-east-1.amazonaws.com/YOUR_USER_POOL_ID \
    --region us-east-1
```

Then require authentication in client portal.

## Monitoring

### CloudWatch Dashboards

Create dashboard for monitoring:

```bash
aws cloudwatch put-dashboard \
    --dashboard-name ClientBillingPortal \
    --dashboard-body file://dashboard.json
```

**Metrics to monitor:**
- Lambda invocations and errors
- API Gateway requests and latency
- DynamoDB read/write capacity
- Cost Explorer API calls (has limits!)

### Alarms

```bash
# Alert on Lambda errors
aws cloudwatch put-metric-alarm \
    --alarm-name client-billing-lambda-errors \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --statistic Sum \
    --period 300 \
    --threshold 5 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1
```

## Cost Analysis

### Portal Operating Costs

**Monthly estimates (per client):**

| Service | Usage | Cost |
|---------|-------|------|
| Lambda (costs API) | 100 invocations | $0.02 |
| Lambda (payment API) | 10 invocations | $0.002 |
| API Gateway | 110 requests | $0.11 |
| DynamoDB | 10 GB storage, on-demand | $2.50 |
| Cost Explorer API | 100 calls | $1.00 |
| S3/Amplify | Static hosting | $0.50 |
| **Total per client** | | **~$4.15/month** |

**Stripe Fees:**
- 2.9% + $0.30 per transaction
- Example: $100 invoice = $3.20 in fees
- Pass through to client or absorb

### Recommended Pricing for Clients

**Option 1: Include in service fee**
- Charge clients flat $10/month "AWS management fee"
- Covers portal costs + your time

**Option 2: Pass through exact costs**
- Bill actual AWS costs + 10% markup
- Portal fee covered by markup

**Option 3: Tiered pricing**
- $0-$50/month AWS: $5 management fee
- $50-$200/month AWS: $10 management fee
- $200+/month AWS: 5% of AWS costs

## Troubleshooting

### Client can't see costs

**Check:**
1. Are cost allocation tags activated? (Takes 24 hours)
2. Are resources properly tagged with ClientOrganization?
3. Check Lambda logs: `/aws/lambda/client-billing-costs`
4. Test API directly with curl

### Payment method won't add

**Check:**
1. Is Stripe API key correctly stored in Secrets Manager?
2. Check Lambda logs: `/aws/lambda/client-billing-payment`
3. Verify Stripe account is activated (not in test mode for production)

### Costs seem wrong

**Remember:**
- Cost Explorer data has 24-hour delay
- Forecasts are estimates, not guarantees
- Some services report costs differently (EC2 vs Lambda)

## Future Enhancements

### Phase 2 Features:

1. **Multi-user access**
   - Add Cognito authentication
   - Role-based access (admin, view-only)

2. **Cost optimization recommendations**
   - Integrate with AWS Trusted Advisor
   - Unused resource detection
   - Rightsizing recommendations

3. **Budget alerts**
   - Set custom budget limits per client
   - Email/SMS when approaching limit
   - Automatic scaling restrictions

4. **Detailed resource explorer**
   - Drill down into specific resources
   - Tag management interface
   - Resource group visualizations

5. **Usage analytics**
   - Trends over time
   - Service utilization charts
   - Cost attribution by team/project

## Support

### For Clients:

Create help page at `/help.html`:
- FAQs about billing
- How to add payment methods
- Understanding cost breakdowns
- Contact information

### For You:

**Documentation:**
- This guide
- AWS Cost Explorer API docs
- Stripe API docs
- Lambda function code comments

**Logs:**
```bash
# View Lambda logs
aws logs tail /aws/lambda/client-billing-costs --follow

# View API Gateway logs
aws logs tail /aws/apigateway/client-billing-portal-api --follow
```

**Testing:**
```bash
# Test cost API
curl "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/costs?clientOrganization=MMP-Toledo&period=current-month"

# Test payment API
curl -X POST "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/payment" \
    -H "Content-Type: application/json" \
    -d '{"action":"get-payment-methods","clientId":"mmp-toledo","clientName":"Minute Man Press Toledo","email":"test@example.com"}'
```

---

**Last Updated:** 2025-12-24
**Version:** 1.0.0
**Contact:** aws@dacvisuals.com
