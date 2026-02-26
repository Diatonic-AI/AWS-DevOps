# connector-partner-central

## Overview

The Partner Central Connector is responsible for integrating with AWS Partner Central APIs to ingest opportunity data and execute write operations (with approval gates).

## Responsibilities

1. **Data Ingestion (Read)**
   - Scheduled sync of opportunities, leads, solutions from Partner Central
   - Store raw payloads in bronze layer (S3)
   - Normalize data to silver layer
   - Track ingestion runs and statistics

2. **Action APIs (Write - Approval-Gated)**
   - Create opportunities
   - Associate opportunities with solutions
   - Start engagement from opportunity
   - All write operations require `ticketId` and approval workflow

3. **Event Emission**
   - Emit CloudEvents to EventBridge on data changes
   - Publish to `pcw.partnercentral.opportunity.*` event types

## Architecture

```
Partner Central API
       │
       ▼
┌─────────────────┐
│   Connector     │
│   Service       │
├─────────────────┤
│ - Scheduler     │
│ - API Client    │
│ - Normalizer    │
│ - Event Emitter │
└─────────────────┘
       │
       ├──► S3 Bronze (raw JSON)
       ├──► S3 Silver (normalized)
       ├──► RDS (metadata)
       └──► EventBridge (events)
```

## Configuration

```yaml
# From platform/config/connectors.yaml
connectors:
  partner_central:
    enabled: true
    mode: "hybrid"          # batch | streaming | hybrid
    schedule_cron: "0 */6 * * *"
    entities:
      - opportunities
      - leads
      - solutions
      - profiles
    write_actions:
      - create_opportunity
      - associate_opportunity
      - start_engagement
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PC_ACCOUNT_ID` | Linked Partner Central account | Required |
| `PC_CATALOG` | Catalog identifier | `AWS` |
| `REDIS_URL` | Redis connection for caching | `redis://localhost:6379` |
| `S3_LAKE_BUCKET` | Data lake bucket name | Required |
| `EVENTBRIDGE_BUS` | EventBridge bus ARN | Required |

## API Endpoints

### Internal API

```
GET  /health              # Health check
GET  /status              # Connector status and last sync
POST /sync                # Trigger manual sync
POST /actions/opportunity # Create opportunity (approval-gated)
```

## Secrets

Credentials stored in Secrets Manager:
- `/{env}/partnercentral/credentials` - API credentials (if applicable)
- IAM role assumption for Partner Central access

## Observability

- Logs: `/pcw/{env}/connectors/partner-central`
- Metrics: `PCW/Connectors/PartnerCentral`
- Traces: X-Ray enabled

## Safety Guardrails

1. **Approval Mode**: All write actions check `action_approval_mode` from config
2. **Ticket Requirement**: Write operations require `ticketId` field
3. **Audit Logging**: Every action logged to `audit_log` table
4. **Rate Limiting**: Respects Partner Central API rate limits with backoff

## Development

```bash
# Run locally
cd services/connector-partner-central
npm install
npm run dev

# Run tests
npm test

# Build container
docker build -t pcw-connector-partner-central .
```

## Dependencies

- `tenant-service`: Tenant context and entitlements
- `authz-service`: Permission validation
- `core.eventing`: EventBridge publishing
- `core.secrets`: Credential retrieval
