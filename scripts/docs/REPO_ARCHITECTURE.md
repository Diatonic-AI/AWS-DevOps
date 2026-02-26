# Repository Architecture Overview

Purpose: Provide a concise mental model for maintainers (human & AI agents) without altering runtime behavior.

## Top-Level Layout
```
AWS-DevOps/
  apps/                     # Application source (frontend, lambda code, services)
  infrastructure/           # Terraform & infra-as-code (legacy + current)
  unified-terraform/        # Target consolidated infra (in progress)
  minio-infrastructure/     # Ancillary local infra experiments
  scripts/                  # Cross-repo operational scripts
  backups/                  # Point-in-time infra/data backups
  containers/               # Container definitions & related artifacts
  config/                   # Standardized environment & platform config (NEW)
  docs/                     # Domain & subsystem documentation
```

## Application Layer (`apps/diatonic-ai-workbench`)
```
apps/diatonic-ai-workbench/
  src/                # Frontend React source
  lambda/             # Backend Lambda code (multi-service)
  services/           # Structured service packages (billing, etc.)
  infra/              # (Transitional) Infra definitions tied to app modules
  scripts/            # App-specific operational scripts
  migrations/         # DynamoDB migration definitions
  public/             # Static assets
```

### Frontend (`src/`)
| Area | Path | Notes |
|------|------|-------|
| Routing & App shell | `src/App.tsx`, `src/components/routing/` | Subdomain + permission routing logic |
| Auth | `src/contexts/AuthContext.tsx`, `src/components/auth/` | Cognito integration |
| Permissions | `src/hooks/usePermissions.ts`, `src/components/permissions/` | Dynamo-driven RBAC |
| Billing | `src/hooks/useSubscription.ts`, `src/components/billing/` | Stripe client integration |
| Education Modules | `src/hooks/useEducationModules.ts` | Dynamic content loading |
| UI Library | `src/components/ui/` | Shadcn-derived primitives |
| Domain Pages | `src/pages/` | High-level route pages |
| AWS Lambda Client | `src/lib/api-client.ts` | API Gateway access |

### Backend (`lambda/`)
| Component | Path | Description |
|-----------|------|-------------|
| Main API Router | `lambda/api/router.ts` | Central dispatch layer |
| Domain Handlers | `lambda/api/handlers/*` | Feature vertical handlers |
| Middleware | `lambda/api/middleware/*` | Auth, tenant, CORS, usage, error |
| Stripe Webhook | `lambda/api/webhook/stripe.js` | Billing events ingestion |
| Permissions Service | `lambda/api/services/permissions.ts` | Permission resolution/lookup |
| Community/Education APIs | `lambda/community-api`, `lambda/education-api` | Specialized stacks |

## Infrastructure Layers
| Folder | Purpose | Status |
|--------|---------|--------|
| `infrastructure/` | Current deployed Terraform definitions (multi-domain) | Active |
| `unified-terraform/` | Normalization & consolidation target | Emerging |
| `infra/` (inside app) | Transitionary module-specific infra (to be merged) | Legacy-to-clean |

## Scripts Classification
| Category | Pattern | Examples |
|----------|---------|----------|
| Deployment | `deploy-*` | `deploy-backend.sh`, `deploy-dev.sh` |
| Environment | `setup-*`, `resolve-*`, `validate-*` | `setup-aws-environment.sh` |
| Data/DB | `dynamodb-*`, `seed-*`, `migrate-*` | `seed-permissions-tables.js` |
| Audit/Security | `security-audit.js`, `cleanup-critical-secrets.sh` | Hardens repo |

## Cleanup & Rationalization Plan (Non-breaking)
| Phase | Action | Impact |
|-------|--------|--------|
| 1 | Add structural docs (this file + env contract) | ✅ Complete |
| 2 | Tag legacy infra modules with deprecation comments | Pending |
| 3 | Introduce CI guard rails (lint, test, tf plan) | Pending |
| 4 | Migrate scattered infra to `unified-terraform/` | Pending |
| 5 | Lock production via explicit promotion pipeline | Pending |

## Agent Operation Heuristics
1. Never modify production infra directly in `infrastructure/` without plan + approval label
2. Prefer adding new infra to `unified-terraform/` unless modifying existing resource
3. Keep frontend feature flags centralized (future: `config/features.json`)
4. When adding AWS resource-dependent code, expose config via environment variable injected through Terraform outputs
5. Avoid duplication—search for existing handler/util before creating new

## Known Technical Debt
| Area | Description | Planned Resolution |
|------|-------------|-------------------|
| Split Lambda variants | Duplicate handler trees under `lambda/deploy-package/` | Consolidate & parameterize build |
| Mixed infra locations | Overlap `infra/`, `infrastructure/`, `unified-terraform/` | Gradual merge |
| Missing CI pipeline | No enforced validation | Add GitHub Actions or equivalent |
| Secret scanning gap | Manual only | Automate in PR workflow |

## Non-Goals of This Cleanup
- No renaming of deployed AWS resources (stability priority)
- No restructuring runtime imports (avoid accidental breakage)
- No environment secret rotation (separate controlled operation)

## Future Enhancements (Safe to Implement Incrementally)
- Add `docs/ARCHIVE/` folder; move stale one-off reports
- Generate dynamic system diagram (scripted) into `docs/`
- Add OpenAPI spec for API Gateway endpoints
- Add permission matrix auto-export script

## Contact & Ownership
| Domain | Owner (Logical) |
|--------|-----------------|
| Frontend Platform | UI/Platform Team |
| Permissions System | Identity & Security |
| Billing | Commerce |
| Infrastructure | DevOps |
| Education Modules | Content Systems |

(Ownership tags to be codified in CODEOWNERS in later step.)
