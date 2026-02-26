# Complete Client Billing System - Quick Start

**Last Updated**: 2026-01-12

---

## What You're Building

A complete, automated client billing system that:

1. **Captures opportunities** from AWS Partner Central automatically
2. **Onboards clients** when deals close
3. **Tracks AWS usage** per client via cost allocation tags
4. **Generates invoices** monthly with Stripe payment processing
5. **Provides client portals** for self-service billing management

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMPLETE WORKFLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  AWS Partner Central    →    Sync Service    →    Billing      │
│  (New Referral)              (Lambda)             (Portal)      │
│                                                                 │
│  1. AWS sends referral                                          │
│     "Acme Corp interested                                       │
│     in cloud migration"                                         │
│                 ↓                                               │
│  2. Auto-sync creates                                           │
│     client in DynamoDB                                          │
│     (status: prospect)                                          │
│                 ↓                                               │
│  3. You close the deal                                          │
│     (update PC to "Closed Won")                                 │
│                 ↓                                               │
│  4. Auto-creates Stripe customer,                               │
│     deploys portal,                                             │
│     sends welcome email                                         │
│                 ↓                                               │
│  5. Client uses AWS resources                                   │
│     (tagged with ClientOrganization)                            │
│                 ↓                                               │
│  6. Monthly billing:                                            │
│     - Collect costs                                             │
│     - Generate invoice                                          │
│     - Charge customer                                           │
│     - Email receipt                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

✅ AWS account with Partner Central access
✅ AWS CLI configured
✅ Node.js 18+ installed
✅ Stripe account (for payments)
✅ DynamoDB table: `client-billing-data`
✅ Existing client billing portal (from previous setup)

---

## Quick Deploy (10 Minutes)

### Step 1: Deploy Partner Central Integration

```bash
cd /home/daclab-ai/DEV/AWS-DevOps

# Deploy sync Lambda + EventBridge schedule
./scripts/deploy-partner-central-integration.sh
```

**This creates:**
- ✅ Lambda function: `partner-central-sync`
- ✅ EventBridge schedule: Runs every 6 hours
- ✅ IAM role with Partner Central permissions
- ✅ DynamoDB integration

### Step 2: Test the Sync

```bash
# Manually trigger sync
aws lambda invoke \
    --function-name partner-central-sync \
    --region us-east-1 \
    /tmp/sync-output.json

# View results
cat /tmp/sync-output.json | jq '.'
```

**Expected output:**
```json
{
  "statusCode": 200,
  "body": "{
    \"message\": \"Sync completed successfully\",
    \"opportunitiesSynced\": 15,
    \"referralsProcessed\": 3,
    \"clientsCreated\": 5,
    \"clientsUpdated\": 10
  }"
}
```

### Step 3: Verify Client Data

```bash
# List all clients
aws dynamodb scan \
    --table-name client-billing-data \
    --filter-expression 'begins_with(PK, :prefix)' \
    --expression-attribute-values '{":prefix":{"S":"CLIENT#"}}' \
    --region us-east-1 | jq '.Items[] | .clientName.S'
```

---

## How It Works

### Automatic Client Lifecycle

#### 1. New Referral Arrives

**Trigger**: AWS Partner Central sends referral

**What happens automatically:**
```
1. EventBridge schedule triggers partner-central-sync Lambda
2. Lambda calls Partner Central API:
   aws partnercentral-selling list-engagement-invitations
3. New referral detected: "Acme Corp"
4. DynamoDB record created:
   {
     PK: "REFERRAL#inv-ABC123",
     companyName: "Acme Corp",
     status: "pending"
   }
5. Notification sent to sales team (TODO: implement)
```

#### 2. Opportunity Qualified

**Trigger**: You update opportunity in Partner Central to "Qualified"

**What happens automatically:**
```
1. Next sync (within 6 hours) detects stage change
2. Client record created if doesn't exist:
   {
     PK: "CLIENT#acme-corp",
     SK: "PROFILE",
     clientName: "Acme Corp",
     status: "prospect",
     partnerCentralOpportunityId: "opp-ABC123",
     partnerCentralStage: "Qualified"
   }
```

#### 3. Deal Closes

**Trigger**: Opportunity moved to "Closed Won"

**What happens (manual for now):**
```bash
# You need to implement client onboarding
# For now, update client status manually:
aws dynamodb update-item \
    --table-name client-billing-data \
    --key '{"PK":{"S":"CLIENT#acme-corp"},"SK":{"S":"PROFILE"}}' \
    --update-expression "SET #status = :status" \
    --expression-attribute-names '{"#status":"status"}' \
    --expression-attribute-values '{":status":{"S":"active"}}' \
    --region us-east-1
```

**Future automation (to be built):**
- Auto-create Stripe customer
- Deploy client-specific portal
- Send welcome email with portal URL
- Create AWS cost allocation tags

#### 4. Monthly Billing

**Existing system handles this:**
- EventBridge triggers monthly invoice generation
- Collects costs via Cost Explorer API
- Creates Stripe invoice
- Charges customer
- Emails receipt

---

## Architecture Overview

### Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     INFRASTRUCTURE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────┐      ┌────────────────┐      ┌──────────┐ │
│  │ EventBridge    │      │ Lambda         │      │ DynamoDB │ │
│  │ Schedule       │─────▶│ partner-       │─────▶│ client-  │ │
│  │ (every 6 hrs)  │      │ central-sync   │      │ billing  │ │
│  └────────────────┘      └────────────────┘      │ -data    │ │
│                                  │                └──────────┘ │
│                                  ▼                              │
│                          ┌────────────────┐                     │
│                          │ Partner        │                     │
│                          │ Central API    │                     │
│                          └────────────────┘                     │
│                                                                 │
│  ┌────────────────┐      ┌────────────────┐      ┌──────────┐ │
│  │ EventBridge    │      │ Lambda         │      │ Stripe   │ │
│  │ Schedule       │─────▶│ client-        │─────▶│ API      │ │
│  │ (1st of month) │      │ billing-costs  │      └──────────┘ │
│  └────────────────┘      └────────────────┘                    │
│                                  │                              │
│                                  ▼                              │
│                          ┌────────────────┐                     │
│                          │ Cost Explorer  │                     │
│                          │ API            │                     │
│                          └────────────────┘                     │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Client Portal (Static Website)                        │    │
│  │  - Amplify or S3 + CloudFront                         │    │
│  │  - Shows costs, usage, invoices                       │    │
│  │  - Stripe payment integration                         │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

**Partner Central → DynamoDB:**
```javascript
// Opportunity in Partner Central
{
  "Id": "opp-ABC123",
  "Customer": {
    "CompanyName": "Acme Corp",
    "Contact": { "Email": "john@acme.com" }
  },
  "LifeCycle": { "Stage": "Qualified" },
  "Project": {
    "ExpectedCustomerSpend": [
      { "Amount": "50000", "CurrencyCode": "USD" }
    ]
  }
}

// Becomes client record in DynamoDB
{
  "PK": "CLIENT#acme-corp",
  "SK": "PROFILE",
  "clientId": "acme-corp",
  "clientName": "Acme Corp",
  "clientOrganization": "Acme-Corp",  // For cost tags
  "status": "prospect",
  "partnerCentralOpportunityId": "opp-ABC123",
  "partnerCentralStage": "Qualified",
  "expectedMonthlySpend": 50000,
  "contactEmail": "john@acme.com"
}
```

**DynamoDB → Cost Explorer → Stripe:**
```javascript
// 1. Get client from DynamoDB
const client = {
  clientOrganization: "Acme-Corp",
  stripeCustomerId: "cus_ABC123"
};

// 2. Query Cost Explorer with tag filter
const costs = await getCosts({
  filters: {
    Tags: {
      Key: "ClientOrganization",
      Values: ["Acme-Corp"]
    }
  },
  timePeriod: "2026-01"
});

// 3. Create Stripe invoice
const invoice = await stripe.invoices.create({
  customer: "cus_ABC123",
  description: "AWS Services - January 2026",
  amount: costs.total * 100,  // Convert to cents
  currency: "usd"
});
```

---

## Database Schema

### DynamoDB Table: client-billing-data

**Item Types:**

```javascript
// 1. Client Profile (synced from Partner Central)
{
  "PK": "CLIENT#acme-corp",
  "SK": "PROFILE",
  "clientId": "acme-corp",
  "clientName": "Acme Corp",
  "clientOrganization": "Acme-Corp",
  "status": "active",  // prospect, active, suspended, churned

  // Partner Central data
  "partnerCentralOpportunityId": "opp-ABC123",
  "partnerCentralStage": "Closed Won",
  "partnerCentralRawData": { /* full opportunity JSON */ },

  // Business data
  "expectedMonthlySpend": 50000,
  "awsAccountId": "123456789012",

  // Billing integration
  "stripeCustomerId": "cus_XYZ789",
  "portalUrl": "https://acme-corp.billing.dacvisuals.com",
  "contactEmail": "john@acme.com",

  // Metadata
  "createdAt": "2026-01-12T10:00:00Z",
  "lastSyncedAt": "2026-01-12T18:00:00Z"
}

// 2. Referral (pending opportunities)
{
  "PK": "REFERRAL#inv-ABC123",
  "SK": "METADATA",
  "invitationId": "inv-ABC123",
  "companyName": "Acme Corp",
  "status": "pending",
  "expirationDate": "2026-02-12",
  "rawData": { /* full referral JSON */ }
}

// 3. Sync State (tracking)
{
  "PK": "SYNC",
  "SK": "OPPORTUNITIES",
  "lastSyncAt": "2026-01-12T18:00:00Z",
  "recordsSynced": 15,
  "syncStatus": "success"
}

// 4. Cost Data (existing from billing portal)
{
  "PK": "mmp-toledo",
  "SK": "2026-01-01_2026-01-31",
  "costData": { /* Cost Explorer response */ }
}
```

---

## Programmatic Management Scripts

You have three powerful scripts available:

### 1. CLI Manager (Interactive)

```bash
./scripts/partner-central-cli-manager.sh
```

**Features:**
- Account overview
- List opportunities
- Create/update opportunities
- Accept/reject referrals
- Associate solutions
- Generate reports

**Command-line mode:**
```bash
./scripts/partner-central-cli-manager.sh overview
./scripts/partner-central-cli-manager.sh opportunities
./scripts/partner-central-cli-manager.sh referrals
```

### 2. Automation Workflows

```bash
./scripts/partner-central-automation.sh [workflow]
```

**Workflows:**
- `daily-sync` - Export all Partner Central data
- `referrals` - Process new referrals
- `pipeline` - Generate opportunity pipeline report
- `map-solutions` - Associate solutions to opportunities
- `stale` - Find opportunities not updated in 90 days
- `weekly` - Generate weekly summary report

**Example:**
```bash
# Run daily sync
./scripts/partner-central-automation.sh daily-sync

# Output: /tmp/partner-central-sync-YYYYMMDD/
#   ├── opportunities.json
#   ├── solutions.json
#   ├── referrals.json
#   └── connections.json
```

### 3. API Setup & Verification

```bash
./scripts/partner-central-api-setup.sh
```

Verifies IAM roles, organization setup, and API access.

---

## Client Onboarding Workflow

### Current State (Semi-Automated)

**When opportunity closes:**

1. **Manual step**: Update Partner Central opportunity to "Closed Won"

2. **Automatic**: Sync Lambda updates client status

3. **Manual step**: Create Stripe customer
   ```bash
   # Use existing Lambda
   aws lambda invoke \
       --function-name client-billing-payment \
       --payload '{
         "action": "setup-payment-method",
         "clientId": "acme-corp",
         "clientName": "Acme Corp",
         "email": "john@acme.com"
       }' \
       /tmp/output.json
   ```

4. **Manual step**: Create AWS cost allocation tags
   ```bash
   # Tag resources with ClientOrganization
   aws resourcegroupstaggingapi tag-resources \
       --resource-arn-list arn:aws:lambda:us-east-1:123456789012:function:acme-function \
       --tags ClientOrganization=Acme-Corp,BillingProject=acme-main
   ```

5. **Manual step**: Deploy client portal
   - Copy portal template
   - Update CLIENT_ORG, CLIENT_ID constants
   - Deploy to unique URL

6. **Manual step**: Send welcome email

### Future State (Fully Automated)

**To implement:**

Create `lambda/client-onboarding/index.js` that:
1. Triggers on client status change to "active"
2. Creates Stripe customer
3. Deploys portal via CDK/CloudFormation
4. Creates cost allocation tags
5. Sends welcome email via SES

---

## Scheduled Jobs

### EventBridge Schedules

```bash
# View all schedules
aws events list-rules --region us-east-1

# Partner Central sync (every 6 hours)
aws events describe-rule \
    --name partner-central-sync-schedule \
    --region us-east-1

# Monthly invoicing (1st of month at 9 AM)
aws events describe-rule \
    --name monthly-invoice-generation \
    --region us-east-1
```

---

## Monitoring & Troubleshooting

### View Logs

```bash
# Partner Central sync logs
aws logs tail /aws/lambda/partner-central-sync --follow --region us-east-1

# Billing costs logs
aws logs tail /aws/lambda/client-billing-costs --follow --region us-east-1

# Payment processing logs
aws logs tail /aws/lambda/client-billing-payment --follow --region us-east-1
```

### Check Sync Status

```bash
# Get last sync state
aws dynamodb get-item \
    --table-name client-billing-data \
    --key '{"PK":{"S":"SYNC"},"SK":{"S":"OPPORTUNITIES"}}' \
    --region us-east-1 | jq '.Item'
```

### List All Clients

```bash
# Show all synced clients
aws dynamodb scan \
    --table-name client-billing-data \
    --filter-expression 'begins_with(PK, :prefix)' \
    --expression-attribute-values '{":prefix":{"S":"CLIENT#"}}' \
    --region us-east-1 | \
    jq -r '.Items[] | "\(.clientName.S) - \(.status.S)"'
```

### Test End-to-End

```bash
# 1. Create test opportunity in Partner Central (web console)
#    - Company: "Test Corp"
#    - Stage: "Prospect"

# 2. Trigger sync
aws lambda invoke \
    --function-name partner-central-sync \
    --region us-east-1 \
    /tmp/sync-test.json

# 3. Verify client created
aws dynamodb get-item \
    --table-name client-billing-data \
    --key '{"PK":{"S":"CLIENT#test-corp"},"SK":{"S":"PROFILE"}}' \
    --region us-east-1

# 4. Update opportunity to "Qualified" in Partner Central

# 5. Trigger sync again

# 6. Verify stage updated
```

---

## Cost Analysis

### Monthly Operating Costs

| Component | Usage | Cost |
|-----------|-------|------|
| Lambda (partner-central-sync) | 120 invocations/month | $0.02 |
| Lambda (client-billing-costs) | 100 invocations/month | $0.02 |
| Lambda (client-billing-payment) | 10 invocations/month | $0.00 |
| EventBridge | 120 events/month | $0.00 |
| DynamoDB | On-demand pricing | $2.50 |
| Cost Explorer API | 100 calls/month | $1.00 |
| API Gateway | 110 requests/month | $0.11 |
| **Total per client** | | **~$3.65/month** |

**Stripe fees:** 2.9% + $0.30 per transaction

**Example:**
Client pays $1,000/month → Stripe fee = $29.30

---

## Next Steps

### Phase 1: Complete Integration (This Week)

- [x] Deploy Partner Central sync Lambda
- [x] Create EventBridge schedule
- [ ] Test with real opportunities
- [ ] Verify client data syncing

### Phase 2: Automate Onboarding (Next Week)

- [ ] Create `client-onboarding` Lambda
- [ ] Auto-create Stripe customers
- [ ] Auto-deploy client portals
- [ ] Send welcome emails via SES

### Phase 3: Enhanced Reporting (Week 3)

- [ ] Build revenue dashboard
- [ ] Partner Central pipeline analytics
- [ ] Client health scoring
- [ ] Churn prediction

### Phase 4: Client Self-Service (Week 4)

- [ ] Add authentication to portals (Cognito)
- [ ] Budget alerts
- [ ] Cost optimization recommendations
- [ ] Support ticketing system

---

## Quick Reference

### Deploy Everything

```bash
# 1. Deploy billing portal infrastructure (if not done)
./scripts/setup-client-billing-portal.sh

# 2. Deploy Partner Central integration
./scripts/deploy-partner-central-integration.sh

# 3. Test sync
aws lambda invoke \
    --function-name partner-central-sync \
    --region us-east-1 \
    /tmp/output.json && cat /tmp/output.json | jq '.'
```

### Common Commands

```bash
# Sync Partner Central now
aws lambda invoke --function-name partner-central-sync --region us-east-1 /tmp/out.json

# List clients
aws dynamodb scan --table-name client-billing-data \
  --filter-expression 'begins_with(PK, :p)' \
  --expression-attribute-values '{":p":{"S":"CLIENT#"}}' | jq -r '.Items[].clientName.S'

# Check last sync
aws dynamodb get-item --table-name client-billing-data \
  --key '{"PK":{"S":"SYNC"},"SK":{"S":"OPPORTUNITIES"}}' | jq '.Item.lastSyncAt.S'

# View logs
aws logs tail /aws/lambda/partner-central-sync --follow
```

---

## Documentation

- **Partner Central API Guide**: `docs/PARTNER-CENTRAL-API-GUIDE.md`
- **Programmatic Quick Start**: `PARTNER-CENTRAL-PROGRAMMATIC-QUICKSTART.md`
- **Client Billing Portal**: `docs/CLIENT-BILLING-PORTAL.md`
- **Integration Architecture**: `docs/PARTNER-CENTRAL-BILLING-INTEGRATION.md` (to be created)

---

**🚀 You now have a complete, automated client billing system!**

**Support:**
- View logs: CloudWatch Logs
- Check status: DynamoDB `client-billing-data` table
- Monitor costs: AWS Cost Explorer
- Issues: aws@dacvisuals.com
