# AWS Partner Central - Programmatic Management Quick Start

**Last Updated**: 2026-01-12

---

## 🎯 What You Can Do Programmatically

AWS Partner Central has **full CLI/API support** for:

✅ **Account Management** - Partner profiles, connections, alliance leads
✅ **Opportunity Management** - Create, update, list, assign opportunities
✅ **Referral Management** - Accept/reject AWS referrals, list engagements
✅ **Solution Management** - List solutions, associate with opportunities
✅ **AWS Insights** - Get AWS-side view of co-sell opportunities
✅ **Automation** - Daily syncs, pipeline reports, CRM integration

---

## 🚀 Quick Start (3 Commands)

### 1. Test Your Access

```bash
# Verify Partner Central CLI is available
aws partnercentral-account help

# Try to get your partner profile
aws partnercentral-account get-partner --region us-east-1
```

### 2. List Your Opportunities

```bash
aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --region us-east-1 \
  --output table
```

### 3. Check for AWS Referrals

```bash
aws partnercentral-selling list-engagement-invitations \
  --catalog AWS \
  --region us-east-1 \
  --output table
```

---

## 📜 Available Scripts (Ready to Use)

You now have 3 comprehensive scripts in `/home/daclab-ai/DEV/AWS-DevOps/scripts/`:

### 1. CLI Manager (Interactive)

```bash
./scripts/partner-central-cli-manager.sh
```

**Features:**
- Interactive menu for all operations
- Account overview
- Opportunity management
- Referral processing
- Solution association
- Reporting

**Command-line mode:**
```bash
./scripts/partner-central-cli-manager.sh overview      # Full account overview
./scripts/partner-central-cli-manager.sh opportunities  # Opportunity dashboard
./scripts/partner-central-cli-manager.sh referrals      # List AWS referrals
./scripts/partner-central-cli-manager.sh help           # Show all commands
```

---

### 2. Automation Workflows

```bash
./scripts/partner-central-automation.sh [workflow]
```

**Available Workflows:**

| Workflow | Command | Purpose |
|----------|---------|---------|
| Daily Sync | `daily-sync` | Export all data (opportunities, referrals, solutions) |
| Referral Processing | `referrals` | Process new AWS referrals |
| Pipeline Report | `pipeline` | Generate opportunity pipeline report |
| Solution Mapping | `map-solutions` | Map solutions to opportunities |
| Stale Cleanup | `stale` | Find opportunities not updated in 90 days |
| Weekly Summary | `weekly` | Generate weekly summary report |
| All Workflows | `all` | Run everything |

**Examples:**
```bash
# Daily data sync
./scripts/partner-central-automation.sh daily-sync

# Generate pipeline report
./scripts/partner-central-automation.sh pipeline

# Run all workflows
./scripts/partner-central-automation.sh all
```

---

### 3. API Setup & Verification

```bash
./scripts/partner-central-api-setup.sh
```

**Verifies:**
- ✅ IAM roles exist and are configured correctly
- ✅ AWS Organization setup
- ✅ Partner Central configuration export
- ✅ CloudFormation stack template generation
- ✅ Role assumption testing
- ✅ Marketplace integration readiness

---

## 📖 Comprehensive Documentation

Full API reference and examples:
```bash
cat docs/PARTNER-CENTRAL-API-GUIDE.md
```

**What's covered:**
- All AWS CLI commands for Partner Central
- JSON templates for creating opportunities
- Automation examples (CRM sync, Slack notifications)
- Best practices (rate limiting, error handling, pagination)
- Troubleshooting guide
- Integration patterns (CI/CD, webhooks, etc.)

---

## 🎓 Common Use Cases

### Use Case 1: Create Opportunity Programmatically

```bash
# 1. Create opportunity JSON
cat > /tmp/new-opportunity.json <<'EOF'
{
  "ClientToken": "unique-$(date +%s)",
  "Customer": {
    "CompanyName": "Acme Corp",
    "CountryCode": "US",
    "Industry": "Technology"
  },
  "LifeCycle": {
    "Stage": "Prospect",
    "TargetCloseDate": "2026-06-30"
  },
  "OpportunityType": "Net New Business",
  "PartnerOpportunityIdentifier": "ACME-2026-001",
  "PrimaryNeedsFromAws": [
    "Co-Sell - Architectural Validation"
  ],
  "Project": {
    "Title": "Cloud Migration Initiative",
    "ExpectedCustomerSpend": [
      {
        "Amount": "100000",
        "CurrencyCode": "USD",
        "Frequency": "Monthly",
        "TargetCompany": "AWS"
      }
    ]
  }
}
EOF

# 2. Create opportunity
aws partnercentral-selling create-opportunity \
  --catalog AWS \
  --region us-east-1 \
  --cli-input-json file:///tmp/new-opportunity.json
```

---

### Use Case 2: Daily Data Export (for CRM sync)

```bash
# Run daily sync
./scripts/partner-central-automation.sh daily-sync

# Output location:
# /tmp/partner-central-sync-YYYYMMDD/
#   ├── opportunities.json
#   ├── solutions.json
#   ├── referrals.json
#   ├── connections.json
#   └── README.md (summary)
```

---

### Use Case 3: Auto-Process AWS Referrals

```bash
# List pending referrals
aws partnercentral-selling list-engagement-invitations \
  --catalog AWS \
  --region us-east-1 \
  --invitation-status Pending

# Accept a referral
aws partnercentral-selling start-engagement-by-accepting-invitation \
  --catalog AWS \
  --region us-east-1 \
  --identifier inv-ABC123 \
  --client-token "accept-$(date +%s)"

# Or use the automation script
./scripts/partner-central-automation.sh referrals
```

---

### Use Case 4: Update Opportunity Stage

```bash
# Update to "Qualified" stage
aws partnercentral-selling update-opportunity \
  --catalog AWS \
  --region us-east-1 \
  --identifier opp-XYZ789 \
  --cli-input-json '{
    "Identifier": "opp-XYZ789",
    "LifeCycle": {
      "Stage": "Qualified"
    },
    "LastModifiedDate": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'
```

---

### Use Case 5: Associate Solution to Opportunity

```bash
# List available solutions
aws partnercentral-selling list-solutions \
  --catalog AWS \
  --region us-east-1

# Associate solution
aws partnercentral-selling associate-opportunity \
  --catalog AWS \
  --region us-east-1 \
  --opportunity-identifier opp-XYZ789 \
  --related-entity-identifier sol-AI-NEXUS \
  --related-entity-type Solutions
```

---

## 🔄 Automation Setup

### Cron Jobs (Recommended)

Add to your crontab (`crontab -e`):

```bash
# Daily sync at 9 AM
0 9 * * * /home/daclab-ai/DEV/AWS-DevOps/scripts/partner-central-automation.sh daily-sync

# Check for referrals every 4 hours
0 */4 * * * /home/daclab-ai/DEV/AWS-DevOps/scripts/partner-central-automation.sh referrals

# Weekly summary on Mondays at 9 AM
0 9 * * 1 /home/daclab-ai/DEV/AWS-DevOps/scripts/partner-central-automation.sh weekly

# Pipeline report daily at 5 PM
0 17 * * * /home/daclab-ai/DEV/AWS-DevOps/scripts/partner-central-automation.sh pipeline
```

### Systemd Timers (Alternative)

```bash
# Create timer
sudo systemctl edit --force --full partner-central-sync.timer

# Add:
[Unit]
Description=Partner Central Daily Sync Timer

[Timer]
OnCalendar=daily
OnCalendar=09:00
Persistent=true

[Install]
WantedBy=timers.target

# Enable and start
sudo systemctl enable --now partner-central-sync.timer
```

---

## 🔌 Integration Examples

### Webhook Integration (Lambda)

```python
# lambda_function.py - Process Partner Central webhooks
import json
import boto3

partnercentral = boto3.client('partnercentral-selling', region_name='us-east-1')

def lambda_handler(event, context):
    # Parse webhook event
    opportunity_id = event['detail']['opportunityId']
    event_type = event['detail-type']

    if event_type == 'Opportunity Created':
        # Auto-assign to team member
        partnercentral.assign_opportunity(
            Catalog='AWS',
            Identifier=opportunity_id,
            Assignee='partner@company.com'
        )

    return {'statusCode': 200}
```

### Slack Integration

```bash
#!/bin/bash
# Send Partner Central updates to Slack

SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Get opportunity count by stage
aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --region us-east-1 \
  --output json | jq -r '
    .OpportunitySummaries |
    group_by(.LifeCycle.Stage) |
    map("- *\(.[0].LifeCycle.Stage)*: \(length) opportunities") |
    join("\n")
  ' | while read -r line; do
    curl -X POST "$SLACK_WEBHOOK" \
      -H 'Content-Type: application/json' \
      -d "{\"text\": \"📊 Partner Central Pipeline Update\n$line\"}"
  done
```

### CRM Sync (Salesforce/HubSpot)

```bash
#!/bin/bash
# Export opportunities and sync to CRM

# Get opportunities
opportunities=$(aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --region us-east-1 \
  --output json)

# Transform to CRM format
echo "$opportunities" | jq '.OpportunitySummaries[] | {
  name: .Customer.CompanyName,
  stage: .LifeCycle.Stage,
  amount: (.Project.ExpectedCustomerSpend[0].Amount // "0"),
  close_date: .LifeCycle.TargetCloseDate,
  source: "AWS Partner Central",
  external_id: .Id
}' | while read -r opportunity; do
  # POST to CRM API
  curl -X POST "https://api.your-crm.com/opportunities" \
    -H "Authorization: Bearer $CRM_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$opportunity"
done
```

---

## 🛠️ Available AWS CLI Commands

### Account Commands (`partnercentral-account`)

```
accept-connection-invitation
cancel-connection
cancel-connection-invitation
create-connection-invitation
get-alliance-lead-contact
get-connection
get-connection-invitation
get-partner
list-connection-invitations
list-connections
```

### Selling Commands (`partnercentral-selling`)

```
assign-opportunity
associate-opportunity
create-opportunity
disassociate-opportunity
get-aws-opportunity-summary
get-engagement-invitation
get-opportunity
get-solution
list-engagement-invitations
list-opportunities
list-solutions
reject-engagement-invitation
start-engagement-by-accepting-invitation
update-opportunity
```

---

## 📊 Example Outputs

### List Opportunities (Table Format)

```
--------------------------------------------------------------------
|                        ListOpportunities                         |
+------------------------------------------------------------------+
||                      OpportunitySummaries                      ||
|+----------------+------------+------------------+---------------+|
|| CompanyName    | Stage      | TargetCloseDate  | Identifier    ||
|+----------------+------------+------------------+---------------+|
|| Acme Corp      | Qualified  | 2026-06-30       | opp-ABC123    ||
|| TechCo Inc     | Prospect   | 2026-08-15       | opp-DEF456    ||
|| Global Systems | Proposal   | 2026-05-01       | opp-GHI789    ||
|+----------------+------------+------------------+---------------+|
```

### Get Opportunity (JSON Format)

```json
{
  "Catalog": "AWS",
  "Id": "opp-ABC123",
  "Customer": {
    "CompanyName": "Acme Corp",
    "CountryCode": "US",
    "Industry": "Technology"
  },
  "LifeCycle": {
    "Stage": "Qualified",
    "TargetCloseDate": "2026-06-30"
  },
  "Project": {
    "Title": "Cloud Migration Initiative",
    "ExpectedCustomerSpend": [
      {
        "Amount": "100000",
        "CurrencyCode": "USD",
        "Frequency": "Monthly"
      }
    ]
  }
}
```

---

## ⚠️ Important Notes

### Region Requirement

**Partner Central APIs use `us-east-1` as the primary region.**

Always include `--region us-east-1` in commands:

```bash
aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --region us-east-1  # ← Required!
```

Or set as default:
```bash
export AWS_REGION=us-east-1
```

### Idempotency

Use `--client-token` for create/update operations:

```bash
--client-token "$(uuidgen)"
```

This prevents duplicate operations if you retry.

### Rate Limiting

Partner Central APIs have rate limits. Implement:
- Exponential backoff on failures
- Delays between bulk operations (0.5-1 second)
- Pagination for large result sets

---

## 🆘 Troubleshooting

### "User is not authorized to perform action"

**Fix**: Ensure IAM permissions include:
```bash
# Attach Partner Central policies
aws iam attach-user-policy \
  --user-name your-user \
  --policy-arn arn:aws:iam::aws:policy/AWSPartnerCentralFullAccess
```

### "Catalog AWS not found"

**Fix**: Ensure you're enrolled in AWS Partner Network and using `--region us-east-1`

### "No partner profile found"

**Fix**: Complete Partner Central enrollment at https://partnercentral.aws.amazon.com/

### Script permissions error

**Fix**: Make scripts executable:
```bash
chmod +x scripts/*.sh
```

---

## 📚 Files Reference

| File | Purpose |
|------|---------|
| `PARTNER-CENTRAL-PROGRAMMATIC-QUICKSTART.md` | This file (quick start) |
| `docs/PARTNER-CENTRAL-API-GUIDE.md` | Complete API reference |
| `scripts/partner-central-cli-manager.sh` | Interactive CLI manager |
| `scripts/partner-central-automation.sh` | Automation workflows |
| `scripts/partner-central-api-setup.sh` | API verification |

---

## 🎯 Next Steps

**Immediate:**
1. Test basic access: `aws partnercentral-account get-partner --region us-east-1`
2. List opportunities: `aws partnercentral-selling list-opportunities --catalog AWS --region us-east-1`
3. Try interactive mode: `./scripts/partner-central-cli-manager.sh`

**This Week:**
1. Set up daily sync automation
2. Configure Slack/email notifications for new referrals
3. Create first opportunity programmatically

**This Month:**
1. Integrate with your CRM
2. Set up automated reporting
3. Build custom dashboards using exported data

---

**🚀 You're now ready for full programmatic control of AWS Partner Central!**

For detailed examples and advanced use cases, see:
```bash
cat docs/PARTNER-CENTRAL-API-GUIDE.md
```
