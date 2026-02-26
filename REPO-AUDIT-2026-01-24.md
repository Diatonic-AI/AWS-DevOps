# AWS-DevOps Repository Audit Report

**Date**: 2026-01-24  
**Repository**: Diatonic-AI/AWS-DevOps  
**Commit**: a8dce07d  
**Auditor**: Kiro AI  
**Correlation ID**: COR:20260124:audit-repo-organization

---

## Executive Summary

This comprehensive audit reveals a **complex, fragmented repository** with significant organizational debt. The repo manages AWS infrastructure, client billing systems, partner integrations, and multiple applications across **2.9GB** of code and assets.

**Critical Findings**:
- 🔴 **P0 Security Issue**: `.env` file tracked in git with secrets
- 🔴 **P0 Fragmentation**: 3 separate Terraform systems (131 files total)
- 🔴 **P0 Documentation**: No root `README.md`
- 🟡 **P1 Bloat**: 79MB `aws-sam-cli-src` directory shouldn't exist here
- 🟡 **P1 Clutter**: 18 root-level config files need organization
- 🟡 **P1 Scripts**: 45 shell scripts lack categorization

**Recommendation**: Immediate action required on P0 issues, followed by systematic reorganization.

---

## Current State Analysis

### Repository Structure

```
AWS-DevOps/
├── apps/                          # Applications (2.4GB submodule + 32KB local)
│   ├── diatonic-ai-workbench/    # 2.4GB Git submodule
│   └── ai-nexus-workbench/       # 32KB Local app
├── lambda/                        # 3 Lambda functions (93MB total)
│   ├── client-billing-costs/     # 30MB
│   ├── client-billing-payment/   # 41MB
│   └── partner-central-sync/     # 22MB
├── unified-terraform/             # PRIMARY Terraform (recommended)
├── production-terraform/          # MINIMAL Terraform (prod-only)
├── infrastructure/terraform/      # LEGACY Terraform (needs migration)
├── AWS_PARTNER_CENTRAL/           # 338MB Separate project
├── aws-sam-cli-src/              # 79MB ⚠️ SHOULD NOT BE HERE
├── scripts/                       # 45 shell scripts (needs organization)
├── config/                        # Environment configs
├── containers/                    # Container definitions
├── client-portal/                 # Client portal code
├── dashboard-frontend/            # Dashboard code
├── minio-infrastructure/          # MinIO terraform
└── [18 root-level config files]  # ⚠️ CLUTTER
```

### Size Breakdown

| Component | Size | Status | Action |
|-----------|------|--------|--------|
| diatonic-ai-workbench | 2.4GB | Git submodule | ✅ Keep |
| AWS_PARTNER_CENTRAL | 338MB | Separate project | 🔄 Consider extraction |
| aws-sam-cli-src | 79MB | AWS SAM source | ❌ Remove |
| Lambda functions | 93MB | Active code | ✅ Keep |
| Terraform files | ~5MB | Infrastructure | 🔄 Consolidate |
| Scripts | ~2MB | Automation | 🔄 Organize |

### Terraform Fragmentation Analysis


**131 Terraform files** spread across **3 separate systems**:

1. **unified-terraform/** (PRIMARY - Recommended)
   - Purpose: Unified management of all infrastructure
   - Workspaces: dev, staging, prod, ai-nexus, minio
   - Modules: core-infrastructure, ai-nexus-workbench, minio, shared
   - Status: ✅ Well-documented, modular, production-ready
   - Backend: S3 + DynamoDB with proper state isolation

2. **production-terraform/** (MINIMAL)
   - Purpose: Production-only resources
   - Status: 🔄 Minimal set, needs import planning
   - Note: Overlaps with unified-terraform

3. **infrastructure/terraform/** (LEGACY)
   - Purpose: Original infrastructure code
   - Subdirs: core, environments, modules, scripts
   - Status: ⚠️ Legacy, needs migration to unified-terraform

**Problem**: Duplication, confusion about which system to use, potential state conflicts.

**Recommendation**: Migrate everything to `unified-terraform/` and archive others.

---

## Critical Issues (P0 - Immediate Action Required)

### 1. 🔴 Security: `.env` File Tracked in Git

**Issue**: `.env` file is tracked despite being in `.gitignore`


```bash
# File header says: "⚠️ WARNING: This file contains secrets! Never commit to git!"
# But it's already committed!
```

**Impact**: Secrets exposed in git history  
**Risk**: High - Stripe keys, AWS credentials potentially exposed

**Action**:
```bash
# 1. Remove from git tracking
git rm --cached .env

# 2. Remove from git history (use BFG or git-filter-repo)
git filter-repo --path .env --invert-paths

# 3. Rotate all secrets in the file
# 4. Verify .gitignore includes .env
# 5. Force push (coordinate with team)
git push --force-with-lease
```

### 2. 🔴 No Root README.md

**Issue**: Repository lacks a root `README.md` file  
**Impact**: New developers have no entry point, unclear repo purpose

**Action**: Create comprehensive `README.md` with:
- Project overview and purpose
- Quick start guide
- Directory structure explanation
- Links to key documentation
- Development workflow
- Deployment procedures

### 3. 🔴 Terraform System Fragmentation

**Issue**: 3 separate Terraform systems causing confusion and potential conflicts


**Impact**: 
- Developers don't know which system to use
- Potential duplicate resource management
- State file conflicts
- Maintenance overhead

**Action**:
1. Audit all resources in each system
2. Migrate `infrastructure/terraform/` → `unified-terraform/`
3. Migrate `production-terraform/` → `unified-terraform/` (prod workspace)
4. Archive old directories: `_archived/terraform-legacy/`
5. Update all documentation to reference only `unified-terraform/`

### 4. 🔴 aws-sam-cli-src Directory (79MB)

**Issue**: Full AWS SAM CLI source code in repository  
**Why it's wrong**: 
- This is a third-party tool, not your code
- Should be installed via package manager
- Adds 79MB of unnecessary bloat
- Creates maintenance burden

**Action**:
```bash
# 1. Remove directory
git rm -r aws-sam-cli-src

# 2. Document SAM CLI installation in README
# Install via: pip install aws-sam-cli
# Or: brew install aws-sam-cli

# 3. Add to .gitignore if needed
echo "aws-sam-cli-src/" >> .gitignore
```

### 5. 🔴 Root-Level Config File Clutter

**Issue**: 18 JSON/YAML/shell files at root level


**Files**:
- `aws-inventory.json`, `aws-inventory-full.json`, `aws-inventory-schema.json`
- `terraform-audit-report.json`, `terraform-audit-schema.json`
- `aws-org-cross-account-policy.json`
- `ccm-s3-bucket-policy.json`
- `organization-admin-policy.json`
- `toledo-consulting-*.json` (5 files)
- `harness-ccm-role.yaml`
- `create-admin-roles-stackset.yaml`
- `trust-policy-stackset.yaml`
- `create-account-users.sh`
- `terraform-audit-report-imports.sh`
- `partner-central-config.txt`
- `partner-central-sync.zip`
- `stripe_appflow_objects.xlsx`

**Action**: Organize into subdirectories:
```bash
mkdir -p policies/ reports/ configs/ archives/

# Move IAM policies
mv *-policy.json policies/
mv *-role.yaml policies/
mv *stackset.yaml policies/

# Move reports and schemas
mv aws-inventory*.json reports/
mv terraform-audit*.json reports/
mv *-schema.json reports/

# Move configs
mv partner-central-config.txt configs/
mv *.xlsx configs/

# Archive old artifacts
mv partner-central-sync.zip archives/
mv *.backup-* archives/
```

### 6. 🔴 Documentation Scattered at Root

**Issue**: 8 markdown files at root with no clear hierarchy


**Files**:
- `AWS-INVENTORY-README.md`
- `TERRAFORM-AUDIT-README.md`
- `COMPLETE-BILLING-SYSTEM-QUICKSTART.md`
- `DEPLOYMENT-COMPLETE.md`
- `TOLEDO_FINAL_ACCESS_INSTRUCTIONS.md`
- `WARP.md`
- `CONTRIBUTING.md`
- `create-iam-users-guide.md`

**Action**: Create `docs/` structure:
```bash
mkdir -p docs/{infrastructure,billing,deployment,guides}

# Organize by domain
mv AWS-INVENTORY-README.md docs/infrastructure/
mv TERRAFORM-AUDIT-README.md docs/infrastructure/
mv COMPLETE-BILLING-SYSTEM-QUICKSTART.md docs/billing/
mv DEPLOYMENT-COMPLETE.md docs/deployment/
mv TOLEDO_FINAL_ACCESS_INSTRUCTIONS.md docs/deployment/
mv create-iam-users-guide.md docs/guides/

# Keep at root
# - README.md (create)
# - CONTRIBUTING.md (keep)
# - WARP.md (operational guide - keep)
```

---

## High Priority Issues (P1 - This Week)

### 1. 🟡 Scripts Organization (45 files)

**Issue**: 45 shell scripts in flat `scripts/` directory


**Categories identified**:
- Deployment scripts (10+): `deploy-*.sh`, `*-deploy.sh`
- Cleanup scripts (5+): `cleanup-*.sh`, `complete-cleanup.sh`
- AWS management (8+): `aws-*.sh`, `fix-*.sh`
- Partner Central (5+): `partner-central-*.sh`
- Monitoring/audit (4+): `audit-*.sh`, `*-monitoring.sh`
- Utility scripts (10+): Various one-off tasks

**Action**: Reorganize into subdirectories:
```bash
cd scripts/
mkdir -p deployment cleanup aws-management partner-central monitoring utilities

# Categorize and move
mv deploy-*.sh *-deploy.sh deployment/
mv cleanup-*.sh complete-cleanup.sh cleanup/
mv aws-*.sh fix-*.sh connect-*.sh aws-management/
mv partner-central-*.sh partner-central/
mv audit-*.sh *-monitoring.sh monitoring/
mv *.sh utilities/  # Remaining scripts

# Update documentation with new paths
```

### 2. 🟡 AWS_PARTNER_CENTRAL Scope (338MB)

**Issue**: Large separate project embedded in this repo  
**Size**: 338MB with own infrastructure, services, docs

**Analysis**:
- Has own `.claude/`, `.github/`, `.grok/` configs
- Complete terraform infrastructure
- Multiple services (gateway-api, stripe-integration, connector-marketplace)
- Extensive PDF documentation (200MB+)

**Options**:
A. **Extract to separate repo** (Recommended if independent lifecycle)
B. **Keep but organize** (If tightly coupled to main project)

**Recommendation**: Evaluate coupling:
- If Partner Central deploys independently → Extract to `Diatonic-AI/partner-central`
- If shares infrastructure/auth → Keep but document relationship

### 3. 🟡 Node.js Dependencies Cleanup

**Issue**: 11 `node_modules/` directories, some not properly ignored

**Action**:
```bash
# Find all node_modules
find . -name "node_modules" -type d

# Ensure all are gitignored
# Add specific paths if needed to .gitignore

# Clean and reinstall where needed
find . -name "node_modules" -type d -prune -exec rm -rf {} \;
# Then reinstall per project: npm install
```

### 4. 🟡 Git Submodule Documentation

**Issue**: `diatonic-ai-workbench` is 2.4GB submodule but no clear docs on:
- How to initialize it
- Update procedures
- Relationship to main repo

**Action**: Add to README.md:
```markdown
## Git Submodules

This repo uses git submodules for large applications:

### diatonic-ai-workbench (apps/diatonic-ai-workbench)
```bash
# Initialize on first clone
git submodule update --init --recursive

# Update to latest
git submodule update --remote apps/diatonic-ai-workbench
```
```

### 5. 🟡 Environment Configuration Clarity

**Issue**: Multiple environment config approaches:
- `config/ENVIRONMENTS.md` (documentation)
- `.env.example` (template)
- `unified-terraform/environments/` (terraform vars)
- Individual `.env` files (scattered)

**Action**: Standardize and document:
1. Create `docs/guides/ENVIRONMENT-SETUP.md`
2. Document precedence and usage
3. Consolidate examples
4. Remove duplicate configs

### 6. 🟡 Backup/Archive Files

**Issue**: Backup files tracked in git:
- `.gitmodules.backup-20250916-235024`
- `test-warp.txt`

**Action**:
```bash
# Remove backup files
git rm .gitmodules.backup-*
git rm test-warp.txt

# Add pattern to .gitignore
echo "*.backup-*" >> .gitignore
```

### 7. 🟡 Lambda Function Organization

**Issue**: 3 Lambda functions at root level, but more in subprojects

**Current**:
```
lambda/
├── client-billing-costs/
├── client-billing-payment/
└── partner-central-sync/
```

**Also found**:
- `infrastructure/terraform/modules/partner-dashboard/lambda/`
- `AWS_PARTNER_CENTRAL/services/*/lambda/`
- `apps/diatonic-ai-workbench/lambda/` (5+ functions)

**Action**: Document Lambda inventory and deployment paths in README

### 8. 🟡 CODEOWNERS File

**Issue**: `CODEOWNERS` exists but needs review for current structure

**Action**: Update after reorganization to reflect new directory structure

---

## Medium Priority Optimizations (P2 - This Month)

### 1. CI/CD Pipeline Documentation

**Gap**: `.github/workflows/` exists but no clear documentation

**Action**: 
- Document existing workflows
- Add workflow setup guide
- Define deployment pipeline clearly

### 2. Terraform State Audit

**Action**: Run comprehensive state audit:
```bash
# Use existing audit script
./scripts/terraform-audit.sh --generate-imports

# Review coverage
jq '.summary' terraform-audit-report.json
```

### 3. Cost Optimization Review

**Action**: Review AWS resources for cost optimization:
- Unused resources
- Over-provisioned instances
- Unattached EBS volumes
- Old snapshots

### 4. Security Audit

**Action**:
- Scan for hardcoded secrets: `git secrets --scan-history`
- Review IAM policies for least privilege
- Audit S3 bucket policies
- Check security group rules

### 5. Dependency Updates

**Action**: Update dependencies across all package.json files:
```bash
# Find all package.json
find . -name "package.json" -not -path "*/node_modules/*"

# Run npm audit in each
# Update outdated packages
```

### 6. Container Organization

**Issue**: `containers/` directory only has `ai-nexus-workbench/`

**Action**: 
- Document container build/deploy process
- Consider consolidating with apps/

### 7. Client Portal Consolidation

**Issue**: Both `client-portal/` and `dashboard-frontend/` exist

**Action**: Clarify relationship or consolidate

### 8. MinIO Infrastructure

**Issue**: `minio-infrastructure/` separate from main terraform

**Action**: Consider migrating to `unified-terraform/modules/minio/`

### 9. Test Coverage Documentation

**Gap**: No clear testing strategy documented

**Action**: Document:
- Unit test locations
- Integration test approach
- E2E test strategy
- Coverage requirements

### 10. Monitoring and Observability

**Action**: Document:
- CloudWatch log groups
- Metrics and alarms
- Dashboards
- Alert procedures

### 11. Disaster Recovery Plan

**Gap**: No documented DR procedures

**Action**: Create `docs/operations/DISASTER-RECOVERY.md`

### 12. Changelog

**Gap**: No CHANGELOG.md

**Action**: Create and maintain CHANGELOG.md following Keep a Changelog format

---

## Recommended Repository Structure

```
AWS-DevOps/
├── README.md                      # ✨ NEW - Main entry point
├── CONTRIBUTING.md                # ✅ Keep
├── CHANGELOG.md                   # ✨ NEW
├── WARP.md                        # ✅ Keep - Operational guide
├── CODEOWNERS                     # 🔄 Update
├── .gitignore                     # 🔄 Update
├── .gitmodules                    # ✅ Keep
│
├── apps/                          # ✅ Applications
│   ├── diatonic-ai-workbench/    # Git submodule
│   └── ai-nexus-workbench/       # Local app
│
├── lambda/                        # ✅ Lambda functions
│   ├── client-billing-costs/
│   ├── client-billing-payment/
│   └── partner-central-sync/
│
├── unified-terraform/             # ✅ PRIMARY infrastructure
│   ├── main.tf
│   ├── modules/
│   ├── environments/
│   └── README.md
│
├── scripts/                       # 🔄 REORGANIZED
│   ├── deployment/
│   ├── cleanup/
│   ├── aws-management/
│   ├── partner-central/
│   ├── monitoring/
│   └── utilities/
│
├── docs/                          # ✨ NEW - Organized documentation
│   ├── infrastructure/
│   │   ├── AWS-INVENTORY.md
│   │   └── TERRAFORM-AUDIT.md
│   ├── billing/
│   │   └── COMPLETE-BILLING-SYSTEM.md
│   ├── deployment/
│   │   ├── DEPLOYMENT-GUIDE.md
│   │   └── TOLEDO-ACCESS.md
│   ├── guides/
│   │   ├── ENVIRONMENT-SETUP.md
│   │   └── IAM-USERS.md
│   └── operations/
│       ├── DISASTER-RECOVERY.md
│       └── MONITORING.md
│
├── config/                        # ✅ Configuration files
│   ├── ENVIRONMENTS.md
│   └── *.json
│
├── policies/                      # ✨ NEW - IAM policies
│   ├── *.json
│   └── *.yaml
│
├── reports/                       # ✨ NEW - Generated reports
│   ├── aws-inventory*.json
│   └── terraform-audit*.json
│
├── archives/                      # ✨ NEW - Historical artifacts
│   ├── terraform-legacy/         # Archived terraform systems
│   └── *.backup
│
├── AWS_PARTNER_CENTRAL/           # 🔄 EVALUATE - Extract or keep?
├── containers/                    # ✅ Keep
├── client-portal/                 # 🔄 EVALUATE - Consolidate?
├── dashboard-frontend/            # 🔄 EVALUATE - Consolidate?
└── minio-infrastructure/          # 🔄 Consider moving to unified-terraform

REMOVED:
├── aws-sam-cli-src/              # ❌ DELETE
├── infrastructure/terraform/      # ❌ ARCHIVE after migration
└── production-terraform/          # ❌ ARCHIVE after migration
```

---

## Action Plan with Priorities

### Phase 1: Critical Security & Cleanup (Week 1)

**Day 1-2: Security**
- [ ] Remove `.env` from git tracking and history
- [ ] Rotate all secrets that were in `.env`
- [ ] Audit for other tracked secrets
- [ ] Run `git secrets --scan-history`

**Day 3-4: Documentation**
- [ ] Create comprehensive `README.md`
- [ ] Create `docs/` directory structure
- [ ] Move and organize documentation files
- [ ] Update all internal doc links

**Day 5: Cleanup**
- [ ] Remove `aws-sam-cli-src/` directory
- [ ] Remove backup files
- [ ] Create and populate `archives/` directory

### Phase 2: Organization (Week 2)

**Day 1-2: Root Level**
- [ ] Create `policies/`, `reports/`, `configs/` directories
- [ ] Move root-level config files to appropriate locations
- [ ] Update scripts that reference moved files

**Day 3-4: Scripts**
- [ ] Create script subdirectories
- [ ] Categorize and move 45 scripts
- [ ] Update documentation with new paths
- [ ] Test critical scripts still work

**Day 5: Git Cleanup**
- [ ] Update `.gitignore` for new structure
- [ ] Update `CODEOWNERS`
- [ ] Commit reorganization

### Phase 3: Terraform Consolidation (Week 3-4)

**Week 3: Audit & Planning**
- [ ] Run terraform state audit on all 3 systems
- [ ] Document all managed resources
- [ ] Create migration plan
- [ ] Identify resource overlaps

**Week 4: Migration**
- [ ] Migrate `infrastructure/terraform/` to `unified-terraform/`
- [ ] Migrate `production-terraform/` to `unified-terraform/`
- [ ] Test all workspaces
- [ ] Archive old terraform directories
- [ ] Update all deployment scripts

### Phase 4: Optimization (Ongoing)

**Month 2:**
- [ ] Evaluate AWS_PARTNER_CENTRAL extraction
- [ ] Consolidate client-portal/dashboard-frontend
- [ ] Clean up node_modules and dependencies
- [ ] Update all package.json dependencies
- [ ] Implement CI/CD improvements

**Month 3:**
- [ ] Security audit and remediation
- [ ] Cost optimization review
- [ ] Disaster recovery documentation
- [ ] Monitoring and observability setup
- [ ] Test coverage improvements

---

## Metrics & Success Criteria

### Before Optimization
- **Total Size**: ~2.9GB
- **Terraform Systems**: 3 separate systems
- **Root Files**: 26 files (18 configs + 8 docs)
- **Scripts**: 45 unsorted scripts
- **Documentation**: Scattered, no entry point
- **Security Issues**: 1 critical (.env tracked)

### After Optimization (Target)
- **Total Size**: ~2.8GB (remove 79MB aws-sam-cli-src)
- **Terraform Systems**: 1 unified system
- **Root Files**: 5-7 essential files only
- **Scripts**: Organized in 6 categories
- **Documentation**: Structured in `docs/` with clear README
- **Security Issues**: 0 critical

### Key Performance Indicators
- ✅ New developer onboarding time: < 30 minutes
- ✅ Deployment clarity: Single source of truth
- ✅ Security posture: No secrets in git
- ✅ Maintainability: Clear structure and documentation
- ✅ Discoverability: Everything has a logical place

---

## Risk Assessment

### High Risk Items
1. **Terraform migration**: Potential state conflicts or resource duplication
   - **Mitigation**: Thorough audit, test in dev first, backup states
   
2. **Secret rotation**: Services may break if secrets not updated everywhere
   - **Mitigation**: Document all secret locations, coordinate rotation

3. **Script path changes**: Automated jobs may break
   - **Mitigation**: Search for hardcoded paths, update systematically

### Medium Risk Items
1. **AWS_PARTNER_CENTRAL extraction**: May break integrations
2. **Large file moves**: Git history may become confusing
3. **Submodule updates**: Team needs to re-initialize

### Low Risk Items
1. **Documentation reorganization**: No runtime impact
2. **Root file cleanup**: Easy to revert if needed
3. **Script categorization**: Paths can be symlinked temporarily

---

## Maintenance Plan

### Daily
- Monitor for new root-level files
- Check for committed secrets (pre-commit hook)

### Weekly
- Review new scripts for proper categorization
- Update documentation for changes

### Monthly
- Dependency updates
- Security audit
- Cost optimization review
- Terraform state audit

### Quarterly
- Comprehensive repo health check
- Documentation review and updates
- Archive old artifacts
- Team feedback on organization

---

## Conclusion

This repository has grown organically and accumulated significant technical debt. The audit reveals **6 critical issues**, **8 high-priority problems**, and **12 optimization opportunities**.

**Immediate actions** (Week 1):
1. Remove `.env` from git and rotate secrets
2. Create root `README.md`
3. Remove `aws-sam-cli-src/`

**Short-term goals** (Month 1):
1. Consolidate to single Terraform system
2. Organize scripts and documentation
3. Clean up root-level clutter

**Long-term vision** (Months 2-3):
1. Evaluate component extraction (AWS_PARTNER_CENTRAL)
2. Implement comprehensive testing
3. Establish maintenance procedures

With systematic execution of this plan, the repository will transform from a fragmented collection into a **well-organized, maintainable, and secure codebase** that supports efficient development and operations.

---

**Audit completed**: 2026-01-24  
**Next review**: 2026-02-24 (post-Phase 3)  
**Contact**: DevOps team for questions or clarifications
