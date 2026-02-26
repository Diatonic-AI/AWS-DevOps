# Data Architecture

## 1) Lakehouse Architecture

### 1.1 Layer Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      PLATINUM LAYER                          │
│  Embeddings │ Knowledge Graph │ ML Features │ Semantic Index │
├─────────────────────────────────────────────────────────────┤
│                        GOLD LAYER                            │
│   Analytics Marts │ KPIs │ Aggregations │ Business Entities  │
├─────────────────────────────────────────────────────────────┤
│                       SILVER LAYER                           │
│   Normalized │ Deduplicated │ Validated │ Type-Safe          │
├─────────────────────────────────────────────────────────────┤
│                       BRONZE LAYER                           │
│   Raw Ingestion │ Immutable │ Full Payloads │ Audit Trail    │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Layer Specifications

| Layer | Format | Partitioning | Retention | Purpose |
|-------|--------|--------------|-----------|---------|
| Bronze | JSON/Parquet | `tenant_id/source/year/month/day` | 2 years | Raw audit trail |
| Silver | Parquet | `tenant_id/entity/year/month` | 5 years | Query-ready entities |
| Gold | Parquet | `tenant_id/mart/date` | 7 years | Analytics consumption |
| Platinum | Parquet + Vector | `tenant_id/type/version` | 1 year | AI/ML features |

## 2) Data Flow

### 2.1 Ingestion Pipeline

```
Source APIs (Partner Central, Marketplace, CRM)
           │
           ▼
    ┌──────────────┐
    │  Connectors  │  (connector-partner-central, connector-marketplace)
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │    Bronze    │  Raw JSON snapshots + metadata
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Data Quality │  Schema validation, anomaly detection
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │    Silver    │  Normalized entities, CDC tracking
    └──────┬───────┘
           │
    ┌──────┴──────┐
    ▼             ▼
┌────────┐   ┌──────────┐
│  Gold  │   │ Platinum │
└────────┘   └──────────┘
```

### 2.2 Processing Modes

| Mode | Trigger | Latency | Use Case |
|------|---------|---------|----------|
| Batch | Scheduled (cron) | Minutes-hours | Historical sync |
| Micro-batch | EventBridge | 1-5 minutes | Near real-time |
| Streaming | Kinesis | Seconds | Real-time dashboards |

## 3) Canonical Entities

### 3.1 Control Plane Entities

```yaml
Tenant:
  - id: uuid
  - slug: string
  - name: string
  - plan: enum
  - status: enum
  - created_at: timestamp

User:
  - id: uuid
  - tenant_id: uuid (FK)
  - email: string
  - display_name: string
  - status: enum

Connector:
  - id: uuid
  - tenant_id: uuid (FK)
  - name: string
  - kind: enum
  - config_json: jsonb
  - status: enum

IngestionRun:
  - id: uuid
  - tenant_id: uuid (FK)
  - connector_id: uuid (FK)
  - entity: string
  - mode: enum (batch|streaming)
  - status: enum
  - stats_json: jsonb
```

### 3.2 Partner Central Entities

```yaml
PartnerCentralOpportunity:
  - id: uuid
  - tenant_id: uuid (FK)
  - pc_opportunity_id: string
  - lifecycle_stage: enum
  - customer_company_name: string
  - expected_revenue_usd: decimal
  - close_date: date
  - partner_solution_id: string
  - engagement_status: enum
  - payload_json: jsonb

PartnerCentralLead:
  - id: uuid
  - tenant_id: uuid (FK)
  - pc_lead_id: string
  - source: string
  - status: enum
  - payload_json: jsonb

PartnerCentralSolution:
  - id: uuid
  - tenant_id: uuid (FK)
  - solution_id: string
  - title: string
  - status: enum
  - payload_json: jsonb
```

### 3.3 Marketplace Entities

```yaml
MarketplaceProduct:
  - id: uuid
  - tenant_id: uuid (FK)
  - entity_id: string
  - product_code: string
  - title: string
  - pricing_model: enum
  - payload_json: jsonb

Subscription:
  - id: uuid
  - tenant_id: uuid (FK)
  - product_id: uuid (FK)
  - subscriber_account_id: string
  - status: enum
  - start_date: timestamp
  - end_date: timestamp

MeterUsage:
  - id: uuid
  - tenant_id: uuid (FK)
  - dimension: string
  - quantity: bigint
  - usage_time: timestamp
  - correlation_id: string
```

## 4) Analytics Layer

### 4.1 Gold Marts

| Mart | Description | Key Metrics |
|------|-------------|-------------|
| pipeline_mart | ACE opportunity funnel | stage conversion, velocity, win rate |
| revenue_mart | Revenue attribution | ARR, MRR, churn, expansion |
| marketing_mart | Lead performance | MQL→SQL, CAC, channel ROI |
| compliance_mart | Audit & compliance | action counts, violations, approvals |

### 4.2 Semantic Layer

```yaml
# metrics.yaml
metrics:
  - name: total_pipeline_value
    description: Sum of expected revenue for open opportunities
    expression: SUM(expected_revenue_usd) WHERE lifecycle_stage != 'closed'
    dimensions: [tenant_id, partner_solution_id, lifecycle_stage]

  - name: win_rate
    description: Percentage of opportunities won
    expression: COUNT(*) WHERE outcome='won' / COUNT(*) WHERE lifecycle_stage='closed'
    dimensions: [tenant_id, quarter, partner_solution_id]
```

## 5) Vector & Embeddings (Platinum Layer)

### 5.1 Use Cases
- Semantic search over Partner Central documentation
- Opportunity similarity for recommendations
- Customer clustering for segmentation

### 5.2 Storage Options

| Option | Pros | Cons | When to Use |
|--------|------|------|-------------|
| pgvector | Integrated with RDS | Scale limits | < 1M vectors |
| OpenSearch Vector | Managed, scalable | Separate service | > 1M vectors |
| Pinecone | Fully managed | External vendor | Rapid prototyping |

### 5.3 Chunking Strategy

```yaml
chunking:
  max_tokens: 800
  overlap_tokens: 120
  separators:
    - "\n## "      # H2 headers
    - "\n### "     # H3 headers
    - "\n\n"       # Paragraphs
    - ". "         # Sentences
```

## 6) Data Quality

### 6.1 Validation Rules

| Rule Type | Example | Action |
|-----------|---------|--------|
| Schema | Required fields present | Reject to DLQ |
| Format | Email matches regex | Flag + continue |
| Business | Revenue > 0 | Warning |
| Freshness | Last update < 24h | Alert |

### 6.2 Quality Scores

```sql
-- DQ score per entity per run
SELECT
  entity,
  ingestion_run_id,
  COUNT(*) as total_records,
  SUM(CASE WHEN is_valid THEN 1 ELSE 0 END)::float / COUNT(*) as quality_score
FROM data_quality_results
GROUP BY 1, 2;
```

## 7) Lineage & Catalog

### 7.1 Lineage Tracking
- Source → Bronze: Connector metadata
- Bronze → Silver: Transform job ID
- Silver → Gold: Mart pipeline ID

### 7.2 Glue Catalog Integration
- All lake tables registered in Glue
- Schema evolution tracked
- Athena/Redshift Spectrum queryable

## 8) Cost Management

### 8.1 Storage Tiering

| Age | Tier | Cost |
|-----|------|------|
| 0-30 days | S3 Standard | $$$ |
| 30-90 days | S3 IA | $$ |
| 90+ days | S3 Glacier IR | $ |

### 8.2 Compute Optimization
- Redshift Serverless: Auto-pause after 5 min idle
- Glue jobs: Spot instances where possible
- Lambda: Right-sized memory allocation
