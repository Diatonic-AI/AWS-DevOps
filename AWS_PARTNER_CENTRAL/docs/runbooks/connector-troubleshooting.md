# Connector Troubleshooting Runbook

## 1) Common Issues

### 1.1 Authentication Failures

**Symptom:** Connector logs show `401 Unauthorized` or `403 Forbidden`

**Partner Central Connector:**
```bash
# Verify IAM role can assume Partner Central access
aws sts get-caller-identity

# Check if account is linked in Partner Central
# (Manual verification in AWS Partner Central console)

# Test Partner Central API access
aws partnercentral-selling list-opportunities \
  --catalog AWS \
  --max-results 1
```

**Resolution:**
1. Verify account linking is complete in Partner Central console
2. Check IAM policy has required permissions:
   - `partnercentral:ListOpportunities`
   - `partnercentral:GetOpportunity`
   - etc.
3. Rotate credentials if compromised

---

### 1.2 Rate Limiting

**Symptom:** `429 Too Many Requests` or `ThrottlingException`

**Diagnosis:**
```bash
# Check recent API call patterns
aws logs filter-log-events \
  --log-group-name /ecs/connector-partner-central \
  --filter-pattern "429" \
  --start-time $(date -d '1 hour ago' +%s000)

# Check CloudWatch metrics for throttling
aws cloudwatch get-metric-statistics \
  --namespace AWS/PartnerCentral \
  --metric-name ThrottledRequests \
  --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Sum
```

**Resolution:**
1. Review current rate limits in API documentation
2. Implement exponential backoff (should be built into connector)
3. Reduce batch size or increase interval between requests
4. Contact AWS support for limit increase if needed

---

### 1.3 Schema Mismatches

**Symptom:** Ingestion succeeds but data is malformed or missing fields

**Diagnosis:**
```sql
-- Find records with unexpected null values
SELECT COUNT(*),
       SUM(CASE WHEN customer_company_name IS NULL THEN 1 ELSE 0 END) as null_company,
       SUM(CASE WHEN expected_revenue_usd IS NULL THEN 1 ELSE 0 END) as null_revenue
FROM partnercentral_opportunities
WHERE updated_at > NOW() - INTERVAL '24 hours';
```

**Resolution:**
1. Compare current API response with expected schema
2. Check if Partner Central API version changed
3. Update connector schema mapping
4. Re-ingest affected records from bronze layer

---

### 1.4 Connectivity Issues

**Symptom:** Timeout errors, connection refused

**Diagnosis:**
```bash
# Test VPC endpoint connectivity (if using)
aws ec2 describe-vpc-endpoints \
  --filters "Name=service-name,Values=*partnercentral*"

# Test NAT gateway (for internet access)
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available"

# Test DNS resolution
nslookup partnercentral.us-east-1.amazonaws.com
```

**Resolution:**
1. Verify security group allows outbound HTTPS (443)
2. Check NAT gateway is healthy
3. Verify VPC endpoint (if used) is correctly configured
4. Check AWS service status page

---

## 2) Connector-Specific Guides

### 2.1 Partner Central Connector

**Health Check:**
```bash
# List recent ingestion runs
SELECT id, entity, status, started_at, ended_at,
       stats_json->>'records_processed' as records
FROM ingestion_runs
WHERE connector_id = (SELECT id FROM connectors WHERE kind = 'partner_central')
ORDER BY started_at DESC
LIMIT 10;
```

**Manual Trigger:**
```bash
# Trigger sync via API
curl -X POST https://api.example.com/v1/connectors/partner-central/sync \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"entity": "opportunities", "mode": "full"}'
```

**Entities Supported:**
| Entity | Read | Write (approval-gated) |
|--------|------|------------------------|
| opportunities | ✓ | create, associate, start_engagement |
| leads | ✓ | - |
| solutions | ✓ | - |
| profiles | ✓ | - |

---

### 2.2 Marketplace Connector

**Health Check:**
```bash
# Verify metering dimensions
aws marketplace-metering get-entitlements \
  --product-code $PRODUCT_CODE

# Check recent metering submissions
SELECT dimension, SUM(quantity), MAX(usage_time)
FROM meter_usage
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY dimension;
```

**Manual Metering (Emergency):**
```bash
# Submit meter usage directly
aws marketplace-metering meter-usage \
  --product-code $PRODUCT_CODE \
  --timestamp $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --usage-dimension $DIMENSION \
  --usage-quantity $QUANTITY
```

---

## 3) Debugging Tools

### 3.1 Enable Debug Logging
```yaml
# In connector config
logging:
  level: DEBUG
  include_payloads: true  # WARNING: may contain PII
```

### 3.2 Inspect Bronze Layer
```bash
# List recent bronze files
aws s3 ls s3://pcw-lake-dev/bronze/partnercentral/opportunities/ \
  --recursive | tail -20

# View raw payload
aws s3 cp s3://pcw-lake-dev/bronze/partnercentral/opportunities/2024/01/15/run-abc123/data.json - | jq .
```

### 3.3 DLQ Investigation
```bash
# List DLQ messages
aws sqs receive-message \
  --queue-url $DLQ_URL \
  --max-number-of-messages 10 \
  --attribute-names All

# Replay DLQ (use with caution)
# Script in: platform/scripts/replay-dlq.py
```

## 4) Escalation Matrix

| Issue Type | First Responder | Escalation |
|------------|-----------------|------------|
| Auth/IAM | Platform team | Security team |
| API errors | Connector team | AWS Support |
| Data quality | Data engineering | Domain SME |
| Performance | SRE | Infrastructure |
