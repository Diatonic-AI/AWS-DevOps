# Cost Guardrails Runbook

## 1) Cost Architecture

### 1.1 Cost Attribution Model

```
Platform Costs
├── Shared Infrastructure (allocated by tenant count)
│   ├── VPC, NAT Gateway
│   ├── EventBridge, Step Functions
│   └── Observability (CloudWatch, X-Ray)
│
├── Tenant-Allocated (metered per tenant)
│   ├── S3 storage (by prefix size)
│   ├── Redshift compute (by query time)
│   ├── Lambda invocations (by request count)
│   └── API Gateway requests
│
└── Usage-Based (billed to tenant plan)
    ├── Records ingested
    ├── AI/ML inference calls
    └── Marketplace metering dimensions
```

### 1.2 Cost Centers

| Cost Center | AWS Services | Allocation Method |
|-------------|--------------|-------------------|
| Compute | Lambda, ECS, Redshift | Per-tenant metering |
| Storage | S3, RDS | Prefix/schema sizing |
| Networking | NAT, VPC endpoints | Flat allocation |
| AI/ML | Bedrock, SageMaker | Per-request tagging |

## 2) Guardrails Configuration

### 2.1 Budget Alerts

```yaml
# platform/config/budgets.yaml
budgets:
  platform_total:
    amount: 10000
    currency: USD
    period: MONTHLY
    alerts:
      - threshold: 50
        notification: slack
      - threshold: 80
        notification: [slack, email]
      - threshold: 100
        notification: [slack, email, pagerduty]

  per_tenant_default:
    amount: 500
    alerts:
      - threshold: 80
        action: notify_tenant_admin
      - threshold: 100
        action: throttle_requests
```

### 2.2 Resource Quotas

```yaml
# Per-tenant limits by plan
quotas:
  foundation:
    max_s3_gb: 50
    max_redshift_rpu_hours: 100
    max_lambda_invocations_per_day: 50000
    max_concurrent_ingestion_runs: 2

  scale:
    max_s3_gb: 500
    max_redshift_rpu_hours: 1000
    max_lambda_invocations_per_day: 500000
    max_concurrent_ingestion_runs: 10

  enterprise:
    max_s3_gb: 5000
    max_redshift_rpu_hours: 10000
    max_lambda_invocations_per_day: 5000000
    max_concurrent_ingestion_runs: 50
```

## 3) Monitoring & Alerting

### 3.1 Cost Explorer Queries

```bash
# Daily cost by service (last 7 days)
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Cost by tenant tag
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=tenant_id
```

### 3.2 CloudWatch Metrics

| Metric | Namespace | Alarm Threshold |
|--------|-----------|-----------------|
| EstimatedCharges | AWS/Billing | > monthly budget * 1.1 |
| ConsumedReadCapacity | AWS/DynamoDB | > provisioned * 0.8 |
| ServerlessDatabaseCapacity | AWS/RDS | > max configured |
| S3 BucketSizeBytes | AWS/S3 | > quota |

### 3.3 Custom CostLedger Metrics

```sql
-- Daily cost by tenant
SELECT
  tenant_id,
  date_trunc('day', usage_date) as day,
  SUM(estimated_cost_usd) as daily_cost
FROM cost_ledger
WHERE usage_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 1, 2
ORDER BY 3 DESC;

-- Top cost drivers
SELECT
  tenant_id,
  resource_type,
  SUM(estimated_cost_usd) as cost
FROM cost_ledger
WHERE usage_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;
```

## 4) Throttling Actions

### 4.1 Automatic Throttling

When tenant exceeds quota:
1. **Soft limit (80%)**: Warning notification
2. **Hard limit (100%)**: Rate limiting applied
3. **Critical (120%)**: Service degradation (read-only mode)

### 4.2 Manual Throttling

```bash
# Enable throttling for a tenant
curl -X POST https://api.example.com/v1/admin/tenants/{tenant_id}/throttle \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"level": "soft", "reason": "Cost overage"}'

# Remove throttling
curl -X DELETE https://api.example.com/v1/admin/tenants/{tenant_id}/throttle \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 5) Cost Optimization Tactics

### 5.1 Storage Optimization

```bash
# Apply S3 lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
  --bucket pcw-lake-$ENV \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "ArchiveOldBronze",
        "Filter": {"Prefix": "bronze/"},
        "Status": "Enabled",
        "Transitions": [
          {"Days": 30, "StorageClass": "STANDARD_IA"},
          {"Days": 90, "StorageClass": "GLACIER_IR"}
        ]
      }
    ]
  }'
```

### 5.2 Compute Optimization

```yaml
# Redshift Serverless auto-pause
redshift:
  min_capacity: 8   # RPU
  max_capacity: 128
  auto_pause: true
  auto_pause_delay_minutes: 5

# Lambda right-sizing
lambda:
  memory_optimization: true
  use_graviton: true
  provisioned_concurrency: 0  # Use on-demand
```

### 5.3 Reserved Capacity

| Service | Commitment | Savings |
|---------|------------|---------|
| RDS Aurora | 1-year reserved | ~30% |
| Redshift Serverless | Committed throughput | ~20% |
| Lambda | Savings Plans | ~17% |

## 6) Emergency Procedures

### 6.1 Cost Spike Response

```
1. Identify source (Cost Explorer → Group by service/tag)
   ↓
2. Determine if legitimate usage or runaway
   ↓
3. If runaway:
   a. Throttle affected tenant/service
   b. Kill long-running queries/jobs
   c. Scale down resources
   ↓
4. Notify stakeholders
   ↓
5. Document and remediate
```

### 6.2 Kill Switches

```bash
# Emergency: Stop all ingestion
aws events disable-rule --name IngestionSchedule

# Emergency: Pause Redshift
aws redshift-serverless update-workgroup \
  --workgroup-name pcw-$ENV \
  --base-capacity 0

# Emergency: Block tenant API access
# (Requires authz-service integration)
curl -X POST https://api.example.com/v1/admin/emergency/block \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"tenant_id": "...", "duration_minutes": 60}'
```

## 7) Reporting

### 7.1 Weekly Cost Report

Generated every Monday, includes:
- Total platform cost vs budget
- Per-tenant cost breakdown
- Top 10 cost drivers
- Week-over-week trends
- Recommendations

### 7.2 Monthly Chargeback

```sql
-- Tenant chargeback report
SELECT
  t.slug as tenant,
  t.plan,
  SUM(cl.estimated_cost_usd) as total_cost,
  SUM(CASE WHEN cl.resource_type = 'compute' THEN cl.estimated_cost_usd END) as compute,
  SUM(CASE WHEN cl.resource_type = 'storage' THEN cl.estimated_cost_usd END) as storage,
  SUM(CASE WHEN cl.resource_type = 'ai_ml' THEN cl.estimated_cost_usd END) as ai_ml
FROM cost_ledger cl
JOIN tenants t ON cl.tenant_id = t.id
WHERE date_trunc('month', cl.usage_date) = date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
GROUP BY 1, 2
ORDER BY 3 DESC;
```
