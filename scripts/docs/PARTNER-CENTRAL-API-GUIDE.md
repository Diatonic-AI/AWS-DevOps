# AWS Partner Central Programmatic Management Guide

## Overview

AWS Partner Central now has full CLI and API support for programmatic management. This guide covers all available operations.

## AWS CLI Commands Available

### Partner Central Services

```bash
aws partnercentral-account   # Account and profile management
aws partnercentral-selling    # Opportunity and referral management
aws partnercentral-benefits   # Benefits and training programs
aws partnercentral-channel    # Channel partner relationships
```

---

## Configuration

### Set Default Region

Partner Central APIs use **us-east-1** as the primary region:

```bash
export AWS_REGION=us-east-1

# Or in ~/.aws/config:
[profile partnercentral]
region = us-east-1
output = json
```

### Verify Access

```bash
# Check authentication
aws sts get-caller-identity

# Test Partner Central access
aws partnercentral-account get-partner --region us-east-1
```

---

## Account Management (`partnercentral-account`)

### Get Partner Profile

```bash
aws partnercentral-account get-partner \
  --region us-east-1 \
  --output json
```

### Get Alliance Lead Contact

```bash
aws partnercentral-account get-alliance-lead-contact \
  --region us-east-1
```

### List Partner Connections

```bash
aws partnercentral-account list-connections \
  --region us-east-1 \
  --max-results 50
```

### Create Connection Invitation

```bash
aws partnercentral-account create-connection-invitation \
  --region us-east-1 \
  --receiver-account-id 123456789012 \
  --message "Let's collaborate on AWS opportunities"
```

### Accept Connection Invitation

```bash
aws partnercentral-account accept-connection-invitation \
  --region us-east-1 \
  --invitation-id inv-abc123
```

### List Connection Invitations

```bash
aws partnercentral-account list-connection-invitations \
  --region us-east-1 \
  --status Pending
```

---

## Opportunity Management (`partnercentral-selling`)

### List Opportunities

```bash
aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --region us-east-1 \
  --max-results 50
```

**Filter by stage:**

```bash
aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --region us-east-1 \
  --lifecycle-stage Qualified
```

### Create Opportunity

```bash
aws partnercentral-selling create-opportunity \
  --catalog AWS \
  --region us-east-1 \
  --cli-input-json file://opportunity.json
```

**opportunity.json template:**

```json
{
  "ClientToken": "unique-idempotency-token",
  "Customer": {
    "CompanyName": "Acme Corporation",
    "CountryCode": "US",
    "Industry": "Technology"
  },
  "LifeCycle": {
    "Stage": "Prospect",
    "TargetCloseDate": "2026-06-30"
  },
  "OpportunityType": "Net New Business",
  "PartnerOpportunityIdentifier": "ACME-2026-Q2-001",
  "PrimaryNeedsFromAws": [
    "Co-Sell - Architectural Validation",
    "Co-Sell - Business Presentation"
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
```

### Get Opportunity Details

```bash
aws partnercentral-selling get-opportunity \
  --catalog AWS \
  --region us-east-1 \
  --identifier opp-123abc456def
```

### Update Opportunity

```bash
aws partnercentral-selling update-opportunity \
  --catalog AWS \
  --region us-east-1 \
  --identifier opp-123abc456def \
  --cli-input-json file://update-opp.json
```

**update-opp.json:**

```json
{
  "Identifier": "opp-123abc456def",
  "LifeCycle": {
    "Stage": "Qualified"
  },
  "LastModifiedDate": "2026-01-12T20:00:00Z"
}
```

### Assign Opportunity

```bash
aws partnercentral-selling assign-opportunity \
  --catalog AWS \
  --region us-east-1 \
  --identifier opp-123abc456def \
  --assignee user@company.com
```

---

## AWS Referral Management

### List Engagement Invitations (AWS Referrals)

```bash
aws partnercentral-selling list-engagement-invitations \
  --catalog AWS \
  --region us-east-1 \
  --max-results 20
```

**Filter by status:**

```bash
aws partnercentral-selling list-engagement-invitations \
  --catalog AWS \
  --region us-east-1 \
  --invitation-status Pending
```

### Get Engagement Invitation Details

```bash
aws partnercentral-selling get-engagement-invitation \
  --catalog AWS \
  --region us-east-1 \
  --identifier inv-789ghi012jkl
```

### Accept AWS Referral

```bash
aws partnercentral-selling start-engagement-by-accepting-invitation \
  --catalog AWS \
  --region us-east-1 \
  --identifier inv-789ghi012jkl \
  --client-token acceptance-$(date +%s)
```

### Reject AWS Referral

```bash
aws partnercentral-selling reject-engagement-invitation \
  --catalog AWS \
  --region us-east-1 \
  --identifier inv-789ghi012jkl \
  --rejection-reason "Not aligned with our current focus areas"
```

---

## Solution Management

### List Partner Solutions

```bash
aws partnercentral-selling list-solutions \
  --catalog AWS \
  --region us-east-1 \
  --max-results 50
```

### Get Solution Details

```bash
aws partnercentral-selling get-solution \
  --catalog AWS \
  --region us-east-1 \
  --identifier sol-456mno789pqr
```

### Associate Solution to Opportunity

```bash
aws partnercentral-selling associate-opportunity \
  --catalog AWS \
  --region us-east-1 \
  --opportunity-identifier opp-123abc456def \
  --related-entity-identifier sol-456mno789pqr \
  --related-entity-type Solutions
```

### Disassociate Solution from Opportunity

```bash
aws partnercentral-selling disassociate-opportunity \
  --catalog AWS \
  --region us-east-1 \
  --opportunity-identifier opp-123abc456def \
  --related-entity-identifier sol-456mno789pqr \
  --related-entity-type Solutions
```

---

## AWS Opportunity Insights

### Get AWS Opportunity Summary

Get AWS-side view of a co-sell opportunity:

```bash
aws partnercentral-selling get-aws-opportunity-summary \
  --catalog AWS \
  --region us-east-1 \
  --related-opportunity-identifier opp-123abc456def
```

This returns AWS's assessment of the opportunity including:
- AWS account ID
- AWS opportunity stage
- AWS team involvement
- Recommended actions

---

## Automation Examples

### Daily Opportunity Sync

```bash
#!/bin/bash
# Daily sync of all opportunities to local storage

OUTPUT_DIR="./partner-data/$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

# Export opportunities
aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --region us-east-1 \
  --max-results 100 \
  --output json > "$OUTPUT_DIR/opportunities.json"

# Export referrals
aws partnercentral-selling list-engagement-invitations \
  --catalog AWS \
  --region us-east-1 \
  --output json > "$OUTPUT_DIR/referrals.json"

# Generate summary
jq '{
  opportunity_count: .OpportunitySummaries | length,
  by_stage: (.OpportunitySummaries | group_by(.LifeCycle.Stage) | map({stage: .[0].LifeCycle.Stage, count: length}))
}' "$OUTPUT_DIR/opportunities.json" > "$OUTPUT_DIR/summary.json"
```

### Auto-Accept Referrals Matching Criteria

```bash
#!/bin/bash
# Automatically accept referrals that match criteria

# Get pending referrals
referrals=$(aws partnercentral-selling list-engagement-invitations \
  --catalog AWS \
  --region us-east-1 \
  --invitation-status Pending \
  --output json)

# Filter and accept matching referrals
echo "$referrals" | jq -r '.EngagementInvitationSummaries[] |
  select(.Payload.Customer.Industry == "Technology") |
  .Id' | while read invitation_id; do

  echo "Auto-accepting referral: $invitation_id"

  aws partnercentral-selling start-engagement-by-accepting-invitation \
    --catalog AWS \
    --region us-east-1 \
    --identifier "$invitation_id" \
    --client-token "auto-accept-$(date +%s)"

  sleep 1  # Rate limiting
done
```

### Weekly Pipeline Report

```bash
#!/bin/bash
# Generate weekly pipeline report

aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --region us-east-1 \
  --max-results 100 \
  --output json | jq -r '
.OpportunitySummaries |
group_by(.LifeCycle.Stage) |
map({
  stage: .[0].LifeCycle.Stage,
  count: length,
  total_value: ([.[] | .Project.ExpectedCustomerSpend[]?.Amount // "0" | tonumber] | add)
}) |
"# Weekly Pipeline Report - " + (now | strftime("%Y-%m-%d")) + "

## Summary by Stage

" + (.[] | "### \(.stage)
- Count: \(.count) opportunities
- Total Expected Value: $\(.total_value)
")
'
```

---

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Partner Central Sync

on:
  schedule:
    - cron: '0 9 * * *'  # Daily at 9 AM UTC
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Sync Partner Central Data
        run: |
          ./scripts/partner-central-automation.sh daily-sync

      - name: Process New Referrals
        run: |
          ./scripts/partner-central-automation.sh referrals

      - name: Generate Pipeline Report
        run: |
          ./scripts/partner-central-automation.sh pipeline
```

---

## Best Practices

### 1. Use Client Tokens for Idempotency

Always include a unique `client-token` when creating or updating resources:

```bash
--client-token "$(uuidgen)"
```

### 2. Implement Rate Limiting

Add delays between bulk operations:

```bash
for id in $opportunity_ids; do
  aws partnercentral-selling update-opportunity ...
  sleep 0.5  # 500ms delay
done
```

### 3. Error Handling

```bash
if ! aws partnercentral-selling create-opportunity ... 2>/tmp/error.log; then
  echo "Error creating opportunity:"
  cat /tmp/error.log
  # Send alert, log to monitoring system, etc.
fi
```

### 4. Pagination for Large Result Sets

```bash
next_token=""
while true; do
  if [ -z "$next_token" ]; then
    result=$(aws partnercentral-selling list-opportunities \
      --catalog AWS \
      --region us-east-1 \
      --max-results 50)
  else
    result=$(aws partnercentral-selling list-opportunities \
      --catalog AWS \
      --region us-east-1 \
      --max-results 50 \
      --starting-token "$next_token")
  fi

  # Process results...
  echo "$result" | jq '.OpportunitySummaries[]'

  # Check for next page
  next_token=$(echo "$result" | jq -r '.NextToken // empty')
  [ -z "$next_token" ] && break
done
```

### 5. Logging and Auditing

```bash
# Log all operations
LOGFILE="./logs/partner-central-$(date +%Y%m%d).log"

{
  echo "$(date): Creating opportunity..."
  aws partnercentral-selling create-opportunity ...
} | tee -a "$LOGFILE"
```

---

## Common Use Cases

### Use Case 1: CRM Integration

Sync Partner Central opportunities to Salesforce/HubSpot:

```bash
# Get opportunities
opportunities=$(aws partnercentral-selling list-opportunities ...)

# Transform to CRM format
echo "$opportunities" | jq '.OpportunitySummaries[] | {
  name: .Customer.CompanyName,
  stage: .LifeCycle.Stage,
  value: .Project.ExpectedCustomerSpend[0].Amount,
  close_date: .LifeCycle.TargetCloseDate,
  owner: .AssignedTo,
  source: "AWS Partner Central"
}'

# Push to CRM API (example with curl)
# curl -X POST https://api.crm.com/opportunities ...
```

### Use Case 2: Slack Notifications for New Referrals

```bash
#!/bin/bash
# Check for new referrals and notify Slack

SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

new_referrals=$(aws partnercentral-selling list-engagement-invitations \
  --catalog AWS \
  --region us-east-1 \
  --invitation-status Pending \
  --output json | jq '.EngagementInvitationSummaries | length')

if [ "$new_referrals" -gt 0 ]; then
  curl -X POST "$SLACK_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{\"text\": \"🎯 You have $new_referrals new AWS referral(s) waiting!\"}"
fi
```

### Use Case 3: Automated Solution Association

```bash
#!/bin/bash
# Auto-associate solutions to opportunities based on keywords

SOLUTION_ID="sol-ai-nexus-workbench"
KEYWORDS=("AI" "ML" "machine learning" "artificial intelligence")

# Get opportunities without solutions
opportunities=$(aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --region us-east-1 \
  --output json)

# Filter and associate
echo "$opportunities" | jq -r --arg sol_id "$SOLUTION_ID" '
  .OpportunitySummaries[] |
  select(.Project.Title | test("AI|ML|machine learning"; "i")) |
  .Id
' | while read opp_id; do
  echo "Associating solution to opportunity: $opp_id"

  aws partnercentral-selling associate-opportunity \
    --catalog AWS \
    --region us-east-1 \
    --opportunity-identifier "$opp_id" \
    --related-entity-identifier "$SOLUTION_ID" \
    --related-entity-type Solutions
done
```

---

## Scripts Available

Your repository now has these ready-to-use scripts:

| Script | Purpose | Usage |
|--------|---------|-------|
| `partner-central-cli-manager.sh` | Interactive CLI manager | `./scripts/partner-central-cli-manager.sh` |
| `partner-central-automation.sh` | Automation workflows | `./scripts/partner-central-automation.sh daily-sync` |
| `partner-central-api-setup.sh` | API configuration verification | `./scripts/partner-central-api-setup.sh` |

### Quick Commands

```bash
# Interactive mode
./scripts/partner-central-cli-manager.sh

# Command mode
./scripts/partner-central-cli-manager.sh overview
./scripts/partner-central-cli-manager.sh opportunities
./scripts/partner-central-cli-manager.sh referrals

# Automation
./scripts/partner-central-automation.sh daily-sync
./scripts/partner-central-automation.sh pipeline
./scripts/partner-central-automation.sh all
```

---

## Troubleshooting

### Error: "User is not authorized"

**Cause**: Missing IAM permissions

**Solution**: Ensure your IAM user/role has Partner Central policies:
- `AWSPartnerCentralFullAccess`
- `AWSPartnerCentralOpportunityManagement`

```bash
# Check current permissions
aws iam list-attached-user-policies --user-name your-user
```

### Error: "Catalog AWS not found"

**Cause**: Wrong region or not enrolled in Partner Central

**Solution**: Ensure you're using `us-east-1` and enrolled as AWS Partner

```bash
aws partnercentral-account get-partner --region us-east-1
```

### Error: "Rate exceeded"

**Cause**: Too many API calls

**Solution**: Implement exponential backoff:

```bash
retry_with_backoff() {
  local max_attempts=5
  local timeout=1
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if "$@"; then
      return 0
    fi

    echo "Attempt $attempt failed. Retrying in ${timeout}s..."
    sleep $timeout
    timeout=$((timeout * 2))
    attempt=$((attempt + 1))
  done

  return 1
}

retry_with_backoff aws partnercentral-selling list-opportunities ...
```

---

## Further Reading

**AWS Documentation:**
- [Partner Central API Reference](https://docs.aws.amazon.com/partner-central/latest/APIReference/)
- [Partner Central User Guide](https://docs.aws.amazon.com/partner-central/latest/userguide/)
- [AWS Partner Network](https://aws.amazon.com/partners/)

**Your Local Documentation:**
- `/home/daclab-ai/DEV/AWS-DevOps/docs/PARTNER-CENTRAL-SETUP.md`
- `/home/daclab-ai/DEV/AWS-DevOps/docs/PARTNER-CENTRAL-CONSOLE-MIGRATION.md`

---

**Last Updated**: 2026-01-12
**Version**: 1.0
