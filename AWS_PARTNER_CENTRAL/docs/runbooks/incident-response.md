# Incident Response Runbook

## 1) Severity Classification

| Severity | Description | Response Time | Escalation |
|----------|-------------|---------------|------------|
| SEV1 | Platform down, data breach | 15 min | Immediate page |
| SEV2 | Major feature broken, tenant impacted | 1 hour | On-call lead |
| SEV3 | Degraded performance, workaround exists | 4 hours | Ticket |
| SEV4 | Minor issue, cosmetic | 24 hours | Backlog |

## 2) Detection Sources

- **CloudWatch Alarms**: Latency, error rates, resource utilization
- **GuardDuty**: Threat detection, anomalous API calls
- **Application logs**: Error patterns, failed auth attempts
- **Customer reports**: Support tickets, Slack channels

## 3) Incident Types

### 3.1 Partner Central API Failures

**Symptoms:**
- `connector-partner-central` logs show 4xx/5xx errors
- Ingestion runs marked as failed
- Stale data in dashboards

**Diagnosis:**
```bash
# Check connector logs
aws logs filter-log-events \
  --log-group-name /ecs/connector-partner-central \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s000)

# Check Partner Central API status
curl -X GET https://status.aws.amazon.com/
```

**Resolution:**
1. Verify AWS Partner Central service status
2. Check IAM role permissions (account linking valid?)
3. Validate API rate limits not exceeded
4. Retry failed ingestion runs manually

**Escalation:**
- If AWS-side issue: Open AWS Support case
- If auth issue: Contact Partner Central admin

---

### 3.2 Marketplace Metering Failures

**Symptoms:**
- `meter_usage` records with `status = 'failed'`
- Billing discrepancies reported by customers
- `MeterUsage` API returning errors

**Diagnosis:**
```bash
# Check metering records
SELECT * FROM meter_usage
WHERE status = 'failed'
AND created_at > NOW() - INTERVAL '24 hours';

# Verify product registration
aws marketplace-metering get-entitlements \
  --product-code <code>
```

**Resolution:**
1. Verify customer entitlement is active
2. Check dimension names match product definition
3. Ensure usage timestamp is within valid window (past 6 hours)
4. Retry with corrected parameters

---

### 3.3 Data Quality Degradation

**Symptoms:**
- DQ scores below threshold (< 95%)
- Anomaly alerts on record counts
- Schema validation failures

**Diagnosis:**
```sql
-- Recent DQ issues
SELECT entity, rule_name, COUNT(*)
FROM data_quality_issues
WHERE created_at > NOW() - INTERVAL '1 day'
GROUP BY 1, 2 ORDER BY 3 DESC;
```

**Resolution:**
1. Identify source of bad data (upstream API change?)
2. Update schema/validation rules if intentional change
3. Quarantine affected records (move to DLQ prefix)
4. Reprocess from bronze layer after fix

---

### 3.4 Authentication/Authorization Failures

**Symptoms:**
- Users unable to login
- 401/403 errors on API calls
- Cognito/IAM errors in logs

**Diagnosis:**
```bash
# Check Cognito user pool status
aws cognito-idp describe-user-pool --user-pool-id <id>

# Check recent auth failures
aws logs filter-log-events \
  --log-group-name /aws/cognito/user-pools/<id> \
  --filter-pattern "USER_AUTH_FAIL"
```

**Resolution:**
1. Verify Cognito pool is healthy
2. Check JWT token validity (expiration, audience, issuer)
3. Validate RBAC policies not recently changed
4. Force token refresh for affected users

---

### 3.5 Cost Spike

**Symptoms:**
- Budget alerts triggered
- Unexpected charges in Cost Explorer
- Resource usage anomalies

**Diagnosis:**
```bash
# Get recent cost by service
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

**Resolution:**
1. Identify cost driver (Redshift, Lambda, S3?)
2. Check for runaway queries or infinite loops
3. Apply immediate throttling if needed
4. Adjust guardrails (per-tenant quotas, concurrent limits)

## 4) Communication

### 4.1 Internal
- **#incident-response** Slack channel for coordination
- Page on-call via PagerDuty for SEV1/SEV2
- Status updates every 30 min during active incident

### 4.2 External (Customer-Facing)
- Status page update for SEV1/SEV2
- Customer notification via email for data-impacting issues
- Post-incident report within 48 hours

## 5) Post-Incident

### 5.1 Timeline
- **24 hours**: Incident summary to stakeholders
- **48 hours**: Draft post-mortem
- **1 week**: Remediation items prioritized
- **2 weeks**: Follow-up on remediation progress

### 5.2 Post-Mortem Template
```markdown
## Incident: [TITLE]
**Date:** YYYY-MM-DD
**Severity:** SEV#
**Duration:** X hours

### Summary
[1-2 sentences describing what happened]

### Impact
- X tenants affected
- Y records impacted
- Z minutes of downtime

### Root Cause
[Technical explanation of why this happened]

### Timeline
- HH:MM - Detection
- HH:MM - Diagnosis
- HH:MM - Mitigation
- HH:MM - Resolution

### Remediation
1. [Action item with owner and due date]
2. [Action item with owner and due date]

### Lessons Learned
- [What went well]
- [What could be improved]
```
