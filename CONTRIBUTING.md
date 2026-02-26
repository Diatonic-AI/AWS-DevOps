# Contributing Guide

This repository maintains production infrastructure and application code. Consistency and safety are mandatory.

## Branch Strategy
```
main            # Always deployable (dev environment auto-deploy)
release/*       # Temporary branch for coordination if needed
feat/<area>-<desc>
fix/<area>-<issue-id>
hotfix/<prod-issue>
chore/<task>
```

## Pull Request Requirements
- ✅ All unit + integration tests pass
- ✅ `npm run lint` & type checks (where applicable)
- ✅ Infrastructure changes include `terraform plan` output in PR description (redacted secrets)
- ✅ Updated docs if behavior/infrastructure changes
- ✅ No secrets / credentials added
- ✅ Added/updated `.env.example` if new variables

## Commit Messages
Format: `<type>(<scope>): <short description>`
```
Types: feat, fix, chore, docs, test, infra, refactor, perf, revert
Example: feat(billing): add subscription status polling hook
```

## Infrastructure Changes
1. Run plan: `terraform plan -out plan.out`
2. Save summary: `terraform show -no-color plan.out > plan.txt`
3. Attach/inline relevant diff sections in PR
4. Tag resources with mandatory tags:
```
Environment, Project=ai-nexus, Owner, Confidentiality=internal/public, CostCenter
```

## Environment Variable Management
- Add new entries to `.env.example`
- Never commit real values
- Prefer SSM/Secrets Manager over plaintext

## Testing Standards
| Layer | Command | Min Coverage |
|-------|---------|--------------|
| Unit (lambda) | `npm test` (lambda pkg) | Key paths touched |
| Integration API | `npm run test:integration` | Critical endpoints |
| E2E (select) | `npm run test:e2e` | Happy path |

## Code Style
- TypeScript strict mode enforced
- Prefer functional components + hooks
- Avoid ambient `any`
- Keep components <250 lines (split otherwise)

## Permissions / Security
- All new AWS IAM policies must be least privilege & justified in PR
- No wildcard `*` on sensitive actions unless documented rationale
- Use parameterized table names with environment suffixes

## Documentation Expectations
Update or create domain docs under `docs/` when:
- New subsystem added
- External integration added/modified
- Deployment procedure changes

## Release Flow
1. Merge to `main`
2. Tag RC: `git tag vX.Y.Z-rc && git push --tags`
3. Validate staging
4. Promote: `git tag vX.Y.Z <rc-commit>`
5. Close milestone & generate changelog

## Automated Checks (Planned)
- Secret scan (trufflehog/gitleaks)
- Terraform static analysis (tfsec)
- Dependency audit (npm audit + custom severity gate)

## Support Files
- `config/ENVIRONMENTS.md` – Environment contract
- `SECURITY_README.md` – Secret & security model

## Questions
Open a discussion or tag @maintainers in PR.
