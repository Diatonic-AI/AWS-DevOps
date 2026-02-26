# AWS Partner Central Wrapper Platform + Internal Marketplace

## What this repo builds
A multi-tenant platform that **wraps AWS Partner Central** into a modular data + ops ecosystem, and provides an **internal module marketplace** (connectors, pipelines, models, dashboards) plus a pathway to publish commercial offerings in **AWS Marketplace**.

### Why this is structurally required
- Partner Central access is mediated by a **linked AWS account** model; that linked account becomes the primary account for Partner Central activities and API usage.  
- Opportunity lifecycles can be automated using Partner Central APIs (e.g., `CreateOpportunity` → associate solution → start engagement).  
- Marketplace product lifecycle + offers can be managed via **AWS Marketplace Catalog API**; usage can be reported via **Marketplace Metering**.

## Quick start (local dev)
1) Copy `platform/config/*.example.yaml` → real files.
2) Run `platform/scripts/bootstrap.sh`
3) Run `platform/scripts/validate-config.py`
4) Deploy infra (dev):
   - `cd infra/terraform/envs/dev`
   - `terraform init`
   - `terraform plan`
   - `terraform apply`
5) Deploy services (dev):
   - `cd infra/ansible`
   - `ansible-playbook -i inventories/dev.ini playbooks/site.yml`

## Guardrails (hard rules)
- No destructive infra changes without explicit `TF_VAR_allow_destroy=true`
- No Partner Central write actions (create/submit/start engagements) without `action_approval_mode=manual`
- Secrets never committed; use AWS Secrets Manager + KMS only.

## Docs
- `docs/spec/aws-partnercentral-wrapper-platform.md` (primary spec)
- `docs/spec/marketplace-strategy.md` (AWS Marketplace listing + metering patterns)
- `docs/spec/security-compliance.md` (IAM, KMS, audit, SOC2-ready controls)
- `docs/spec/tenancy-model.md` (multi-tenant architecture)
- `docs/spec/data-architecture.md` (lakehouse layers, canonical entities)
- `docs/runbooks/incident-response.md` (incident handling procedures)
- `docs/runbooks/connector-troubleshooting.md` (connector debugging)
- `docs/runbooks/cost-guardrails.md` (cost management)

## Repository Structure

```
├── docs/                      # Specifications, runbooks, diagrams
├── platform/
│   ├── config/                # Platform configuration (YAML)
│   ├── registry/              # Module marketplace registry
│   └── scripts/               # Bootstrap and validation scripts
├── infra/
│   ├── terraform/             # Infrastructure as Code
│   │   ├── envs/              # Environment roots (dev/stage/prod)
│   │   └── modules/           # Reusable Terraform modules
│   └── ansible/               # Configuration management
├── schemas/
│   ├── db/                    # Database migrations (SQL)
│   ├── openapi/               # REST API schema
│   ├── graphql/               # GraphQL schema
│   └── events/                # CloudEvents contracts
├── services/                  # Microservices
│   ├── gateway-api/           # Unified API facade
│   ├── tenant-service/        # Tenant lifecycle
│   ├── authz-service/         # Authorization
│   ├── connector-partner-central/  # Partner Central integration
│   ├── connector-marketplace/ # Marketplace integration
│   └── ...
└── .github/workflows/         # CI/CD pipelines
```

## Key Services

| Service | Purpose |
|---------|---------|
| `gateway-api` | REST/GraphQL facade, auth, rate limiting |
| `tenant-service` | Tenant provisioning, plans, entitlements |
| `authz-service` | RBAC/ABAC policy evaluation |
| `connector-partner-central` | Partner Central data ingestion + actions |
| `connector-marketplace` | Catalog + metering + entitlements |
| `pipeline-orchestrator` | Step Functions workflows |
| `analytics-service` | Metrics, semantic layer, BI exports |
| `agent-hub` | RAG + LLM tools + prompt registry |

## Configuration

Key configuration files in `platform/config/`:

- `platform.yaml` - Core platform settings
- `connectors.yaml` - Connector configurations
- `products.yaml` - Plans and pricing tiers
- `policies.yaml` - Authorization policies
- `feature-flags.yaml` - Feature toggles

## AWS Services Used

- **Compute**: Lambda, ECS Fargate
- **Storage**: S3 (data lake), Aurora PostgreSQL, Redshift Serverless
- **Eventing**: EventBridge, Step Functions, SQS
- **Security**: IAM, KMS, Secrets Manager, Cognito
- **Observability**: CloudWatch, X-Ray
- **Integration**: Partner Central APIs, Marketplace APIs
