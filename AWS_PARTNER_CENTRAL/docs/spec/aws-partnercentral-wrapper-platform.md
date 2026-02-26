# AWS Partner Central Enterprise Data Platform Wrapper (v1.1)

## 0) Core thesis
Partner Central becomes an **integration domain** (source for partner program, ACE opportunity workflows, analytics inputs).  
This platform adds:
- multi-tenant governance
- canonical data models + lakehouse layers (bronze/silver/gold/platinum)
- internal module marketplace (connectors, pipelines, AI agents, dashboards)
- marketplace packaging (internal + AWS Marketplace readiness)

## 1) AWS primitives we explicitly wrap
### 1.1 Partner Central API (integration + actions)
- Use Partner Central service APIs for partner workflows and CRM automation.
- Key action flows:
  - Opportunities: Create → Associate solution → Start engagement
  - Read surfaces: opportunities, solutions, profiles, etc. (expand per API scope)

**Account linkage assumption**: The partner must link a dedicated AWS account and use IAM roles/permissions to access Partner Central in-console and APIs. (This repo provisions least-privilege roles/policies, but linkage is an organizational prerequisite.)

### 1.2 AWS Marketplace API surfaces (seller-side)
- Catalog API: programmatic product + offer lifecycle management.
- Metering API: submit usage (SaaS / usage-based dimensions).
- Entitlement patterns: grant/validate subscriber access (via entitlement service integration patterns).

## 2) Platform architecture (layers)
### 2.1 Layers
- Presentation: UI portal, embedded dashboards, developer portal
- Orchestration: event bus, workflow engine, connector scheduler, retries/DLQs
- Intelligence: agent hub, prompt registry, RAG, scoring/forecast models
- Data management: ingestion, cleaning, DQ gates, lineage, schema evolution
- Storage/compute: S3 lake, RDS (operational), Redshift (analytics), vector
- Integration: Partner Central connector suite + Marketplace connector suite

### 2.2 Control plane vs data plane
- Control plane: tenants, plans, entitlements, module registry, policies
- Data plane: ingestion runs, lake partitions, transforms, analytics, embeddings

## 3) Internal module marketplace (first-class feature)
### 3.1 Module types
- Connectors: partner central, marketplace, CRM, marketing, finance
- Pipelines: bronze→silver, silver→gold, feature store, embeddings
- Dashboards: KPI packs, ACE pipeline health, marketing ROI
- Agents/tools: partner advisor, ops agent, support agent, doc agent

### 3.2 Module packaging contract
- `schemas/registry/module-manifest.yaml` is the canonical manifest.
- Registry stores:
  - semantic version
  - dependencies
  - permissions requested
  - cost footprint hints
  - tenancy compatibility
  - data entities produced/consumed

## 4) Tenancy model
- Tenant hierarchy: Enterprise → Org → Workspace → User
- Isolation: “pooled compute, isolated data” by default:
  - RDS: tenant_id + RLS
  - S3: prefix partitioning + bucket policies
  - Redshift: schema-per-tenant (enterprise) or RLS (org) (configurable)
- Tenant provisioning is idempotent and driven by `tenant-service`.

## 5) Data architecture
### 5.1 Lakehouse layers
- Bronze: raw API payloads + immutable snapshots
- Silver: normalized entities + dedupe + validated
- Gold: analytics-ready marts (pipeline, revenue, marketing, compliance)
- Platinum: embeddings, KG edges, model features

### 5.2 Canonical entities (minimum viable)
- Tenant, User, Role, Policy, Connector, IngestionRun
- PartnerCentralOpportunity, PartnerCentralLead, PartnerCentralSolution
- MarketplaceProduct, MarketplaceOffer, Subscription, Entitlement, MeterUsage
- AuditLog, CostLedger, DataQualityIssue, LineageEdge

## 6) Services (what we actually build)
- `gateway-api`: unified REST/GraphQL facade
- `tenant-service`: provisioning + plan/entitlements
- `authz-service`: ABAC/RBAC policies; OPA-compatible output
- `connector-partner-central`: read/write integration + ingestion
- `connector-marketplace`: catalog + metering + entitlement workflows
- `pipeline-orchestrator`: schedules runs; StepFunctions bridge; DLQs
- `data-quality-service`: rules, profiling, anomaly detection
- `analytics-service`: semantic metrics, exports, KPI packs
- `agent-hub`: prompt registry, tools, RAG, guardrails
- `ui-portal`: white-label portal + dashboards

## 7) Non-negotiable guardrails
- Action approval gates for Partner Central writes
- Full audit logging (who/what/when/why)
- Cost guardrails: budgets + throttles + per-tenant quotas
- Data classification tags; PII redaction policy enforced in pipelines

## 8) Implementation phases (deliverables-driven)
### Phase A: Foundation (Infra + tenancy + registry)
- Terraform: VPC, KMS, Secrets, EventBridge, StepFunctions, RDS, S3
- Core services: tenant-service, authz-service, registry seed
### Phase B: Partner Central wrapper (Connector + ingestion)
- Implement read surfaces first, then write actions behind approval mode
### Phase C: Marketplace wrapper (Catalog + metering + entitlement)
- Implement seller tooling + internal marketplace packaging
### Phase D: Intelligence layer (agents + RAG)
- Agent hub + embeddings + knowledge packs
### Phase E: GA hardening
- compliance posture, DR, perf tests, SLOs
