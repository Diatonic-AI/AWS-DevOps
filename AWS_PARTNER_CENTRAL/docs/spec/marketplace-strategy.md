# Marketplace Strategy (Internal + AWS Marketplace)

## 1) Two marketplaces
### 1.1 Internal marketplace (built into platform)
- Modules (connectors/pipelines/dashboards/agents) are installed per-tenant
- Entitlements are enforced via `tenant-service` + `authz-service`

### 1.2 External marketplace (AWS Marketplace listing)
- Your platform can be packaged as:
  - SaaS Subscription
  - SaaS Contract
  - Container-based (EKS/ECS)
  - AMI (if needed)
- AWS Marketplace Catalog API automates product/offer lifecycle operations.

## 2) Metering patterns
- For usage-based plans, emit usage via Marketplace Metering APIs.
- Internal `CostLedger` correlates:
  - platform usage (API calls, compute time, storage GB)
  - metering dimensions (e.g., records ingested, seats, actions executed)

## 3) Offer patterns
- Private offers supported via marketplace connector workflows.
- Trial experiences are implemented as tenant plan transitions + feature flags.