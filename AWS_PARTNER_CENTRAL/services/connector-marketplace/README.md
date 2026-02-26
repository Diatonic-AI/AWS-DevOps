# connector-marketplace

## Overview

The Marketplace Connector integrates with AWS Marketplace APIs for catalog management, usage metering, and entitlement validation.

## Responsibilities

1. **Catalog Management**
   - Sync products and offers from Marketplace Catalog API
   - Track subscriptions and entitlements
   - Store catalog data in data lake

2. **Usage Metering**
   - Emit usage records via Marketplace Metering API
   - Correlate internal usage tracking with Marketplace dimensions
   - Handle metering failures and retries

3. **Entitlement Validation**
   - Validate subscriber access for SaaS products
   - Check entitlement status on authentication

## Architecture

```
Marketplace APIs (Catalog + Metering)
              │
              ▼
     ┌─────────────────┐
     │   Connector     │
     │   Service       │
     ├─────────────────┤
     │ - Catalog Sync  │
     │ - Meter Emitter │
     │ - Entitlement   │
     └─────────────────┘
              │
              ├──► S3 (catalog data)
              ├──► RDS (meter_usage table)
              └──► EventBridge (events)
```

## Configuration

```yaml
# From platform/config/connectors.yaml
connectors:
  marketplace:
    enabled: true
    schedule_cron: "0 2 * * *"
    entities:
      - products
      - offers
      - subscriptions
      - entitlements
    write_actions:
      - publish_change_set
      - emit_meter_usage
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MP_PRODUCT_CODE` | Marketplace product code | Required |
| `S3_LAKE_BUCKET` | Data lake bucket name | Required |
| `EVENTBRIDGE_BUS` | EventBridge bus ARN | Required |

## Metering API

### Emit Usage

```bash
POST /meter
Content-Type: application/json

{
  "dimension": "records_processed",
  "quantity": 1000,
  "usageTime": "2024-01-15T10:00:00Z",
  "correlationId": "batch-run-123"
}
```

### Response

```json
{
  "meteringRecordId": "uuid",
  "status": "accepted"
}
```

## Metering Dimensions

Common dimensions configured in the product:

| Dimension | Description | Unit |
|-----------|-------------|------|
| `records_processed` | Records ingested | 1000 records |
| `api_requests` | API calls made | 1000 requests |
| `storage_gb` | Storage used | GB |
| `ai_queries` | AI/ML inference calls | Query |

## Entitlement Check Flow

```
1. User authenticates (Cognito)
   ↓
2. Gateway calls entitlement check
   ↓
3. Connector queries Marketplace Entitlement API
   ↓
4. Returns entitlement status + dimensions
   ↓
5. AuthZ service applies limits
```

## Safety Guardrails

1. **Metering Validation**: Quantity > 0, timestamp within 6-hour window
2. **Retry Logic**: Failed metering stored locally, retried with backoff
3. **Audit Trail**: All metering events logged
4. **Deduplication**: Correlation ID prevents duplicate submissions

## Development

```bash
cd services/connector-marketplace
npm install
npm run dev
npm test
```

## Dependencies

- `tenant-service`: Product/subscription mapping
- `authz-service`: Entitlement-based access control
- `core.eventing`: Event publishing
