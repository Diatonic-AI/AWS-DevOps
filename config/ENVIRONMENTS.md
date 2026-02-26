# Environment Architecture

This document defines the standardized environments for the Diatonic AI platform after repository cleanup.

## Environments

| Name | Purpose | Branch Source | Deployment Trigger | URL Pattern | Infrastructure State |
|------|---------|---------------|--------------------|-------------|----------------------|
| development | Active feature integration & internal QA | `main` (continuous) | Merge to `main` / Manual | *.dev.diatonic.ai | Shared, mutable |
| staging | Pre-production validation / release candidate | Tagged release | Git tag `v*.*.*-rc` | *.staging.diatonic.ai | Immutable per release |
| production | Live customer traffic | Tagged release | Git tag `v*.*.*` | *.diatonic.ai | Immutable (IaC locked) |

## Branching & Release Flow

1. Feature branches: `feat/<area>-<short-desc>`
2. Integration: Merge feature PRs into `main` (requires passing tests + lint + infra plan)
3. Release Candidate: Create tag `vX.Y.Z-rc` -> deploy to staging
4. Promotion: Tag `vX.Y.Z` -> deploy to production (reuses staging artifact hash)
5. Hotfix: `hotfix/<issue>` -> cherry-pick to `main` + retag patch version

## Infrastructure Promotion

| Layer | Dev | Staging | Prod | Notes |
|-------|-----|---------|------|-------|
| Terraform Backend | Local / S3 (dev bucket) | S3 (staging bucket) | S3 (prod bucket + DynamoDB lock) | Strict state separation |
| Amplify Frontend | Auto build | Manual approve | Manual approve | Artifact hash pinned |
| Lambda/API | On merge | From RC artifact | From RC artifact | No direct prod build |
| DynamoDB Tables | Shared dev tables | Isolated staging prefix | Isolated prod prefix | Migration gating |
| EventBridge | Dev bus | Staging bus | Prod bus | Rule parity enforced |

## Environment Variable Precedence
```
# 1. Secrets Manager (runtime secret values)
# 2. SSM Parameter Store (non-secret config)
# 3. Terraform Outputs (injected during build)
# 4. .env.$NODE_ENV (local dev only)
# 5. Fallback defaults embedded in code (minimal)
```

## Required Core Variables (Resolved at Build)
```
VITE_APP_ENV
VITE_API_GATEWAY_URL
VITE_TENANT_ID
VITE_USER_POOL_ID
VITE_IDENTITY_POOL_ID
VITE_USER_POOL_CLIENT_ID
VITE_STRIPE_PUBLISHABLE_KEY
VITE_PRICING_TABLE_ID
```

## Security Controls
- No `.env` committed beyond `.env.example`
- Automated scanner blocks PR if secrets found
- Build pipeline validates required var matrix before artifact publish

## Migration Strategy
1. Capture current Terraform workspaces & state locations
2. Create new remote state buckets per env
3. Import existing prod resources (tag them with `Environment=production`)
4. Freeze ad-hoc changes (enable CloudTrail drift detection)
5. Enforce `terraform plan` in PR CI

## Lifecycle Policies
| Artifact | Retention | Tool |
|----------|-----------|------|
| Lambda zips | 30 days non-prod | S3 lifecycle |
| Build artifacts | 90 days | Artifact registry |
| Terraform plans | 14 days | CI artifact retention |
| Logs (app) | 14 days dev / 30 staging / 90 prod | CloudWatch + export |

## Observability Baseline
- Request tracing header: `x-ai-nexus-trace-id`
- Structured log fields: `timestamp, level, service, env, traceId, userId, route, latencyMs`
- Error budget dashboard: latency p95, error %, cold start count

## Naming Conventions
```
<project>-<env>-<component>-<purpose>
Examples:
  ai-nexus-dev-dynamo-users
  ai-nexus-staging-lambda-main-api
  ai-nexus-prod-eventbus-stripe
```

## Clean Repo Guiding Principles
- Runtime code separated from infra (`/apps`, `/infrastructure`, `/unified-terraform`)
- Single source-of-truth env config (`/config` + Terraform)
- Documentation collocated but categorized (`/docs/<domain>` soon)
- Deterministic deployments (same artifact -> staging & prod)

## Next Steps (Planned Automation)
- Add CI pipeline definitions
- Add environment validation script integration
- Add artifact integrity checksum verification
