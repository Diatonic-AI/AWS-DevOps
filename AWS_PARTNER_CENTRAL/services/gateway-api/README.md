# gateway-api

## Overview

The Gateway API is the unified REST/GraphQL facade for the platform. It handles authentication, authorization, rate limiting, and routes requests to internal services.

## Responsibilities

1. **API Facade**
   - REST API (OpenAPI 3.0)
   - GraphQL endpoint
   - WebSocket support for real-time updates

2. **Authentication & Authorization**
   - JWT validation (Cognito)
   - Tenant context extraction
   - Permission checking via AuthZ service

3. **Rate Limiting**
   - Per-tenant rate limits based on plan
   - Quota enforcement

4. **Request Routing**
   - Route to internal services
   - Response aggregation

## Architecture

```
                 ┌─────────────────┐
   Client ──────►│   API Gateway   │
                 │   (AWS)         │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  Gateway API    │
                 │  Service        │
                 ├─────────────────┤
                 │ - Auth Middleware│
                 │ - Rate Limiter  │
                 │ - Router        │
                 └────────┬────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   ┌──────────┐    ┌──────────┐    ┌──────────┐
   │ tenant-  │    │connector-│    │analytics-│
   │ service  │    │ services │    │ service  │
   └──────────┘    └──────────┘    └──────────┘
```

## Endpoints

### REST API

```
# Health
GET  /health
GET  /config

# Tenants
GET  /v1/tenants
GET  /v1/tenants/:id
POST /v1/tenants

# Partner Central
GET  /v1/partner-central/opportunities
POST /v1/partner-central/opportunities
GET  /v1/partner-central/opportunities/:id

# Marketplace
POST /v1/marketplace/meter-usage

# Analytics
GET  /v1/analytics/pipeline-metrics
```

### GraphQL

```
POST /graphql
GET  /graphql (playground in dev)
```

### WebSocket

```
WS /ws/events
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `3000` |
| `COGNITO_USER_POOL_ID` | Cognito pool ID | Required |
| `COGNITO_CLIENT_ID` | Cognito client ID | Required |
| `AUTHZ_SERVICE_URL` | AuthZ service endpoint | Required |
| `REDIS_URL` | Redis for rate limiting | Required |

## Rate Limiting

Limits by plan:

| Plan | Requests/Day | Burst/Minute |
|------|--------------|--------------|
| Foundation | 25,000 | 100 |
| Scale | 250,000 | 500 |
| Enterprise | 5,000,000 | 2000 |

## Development

```bash
cd services/gateway-api
npm install
npm run dev

# Run with hot reload
npm run dev:watch

# Run tests
npm test

# Build
npm run build
```

## Dependencies

- `tenant-service`: Tenant resolution
- `authz-service`: Permission validation
- All connector services
- `analytics-service`: Metrics endpoints
