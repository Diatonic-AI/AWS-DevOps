# AWS Partner Central Console Migration - Execution Checklist

**Based on AWS Official Documentation (2025)**

This guide follows AWS's recommended approach for migrating to **Partner Central in the AWS Console** with IAM-based access control.

---

## ⚠️ Important: Dedicated Account Required

AWS **strongly recommends** using a **dedicated member account** for Partner Central, **NOT**:
- ❌ Your organization management account
- ❌ Production/dev/sandbox accounts
- ❌ Marketplace buyer accounts
- ❌ Personal AWS accounts

**Why?** Partner Central resources (opportunities, history, invitations) are **permanently tied** to the linked account and **cannot be transferred** later.

**Your Current Setup:**
- **Management Account**: 313476888312 (DiatonicAI) - ⚠️ **Not recommended** for Partner Central
- **Recommended Alternative**: Create a new dedicated account OR use 916873234430 (Diatonic Dev)

**Decision Required**: Which account will be your Partner Central linked account?

---

## Phase 0: Decision & Roles (Before Any Technical Work)

### ✅ Phase 0.1: Choose Your Partner Central Account

**Checklist:**
- [ ] Dedicated AWS account identified (account ID: _____________)
- [ ] Account is on **Paid Plan** (required for linking)
- [ ] Account is **NOT** the organization management account
- [ ] Account is **NOT** used for production workloads
- [ ] Billing owner identified: _____________
- [ ] IAM ownership documented: _____________

**Recommended for You:**
```
Option 1 (BEST): Create new dedicated account "DiatonicPartnerCentral"
  - Clean slate, no conflicts
  - Can still use other accounts as "builder accounts" for solutions

Option 2: Use existing 916873234430 (Diatonic Dev)
  - Already exists, save time
  - Risk: dev workloads share the account with Partner Central
```

### ✅ Phase 0.2: Identify Key Personnel

**Required Roles:**
- [ ] **IAM Administrator** (IT/Security): _____________
  - Responsibilities: Create/manage IAM roles, trust policies, access control

- [ ] **Alliance Lead / Cloud Admin** (Partner Central): _____________
  - Responsibilities: Link account, map users, manage Partner Central operations

**Deliverable:** Named owners documented and aligned on responsibilities

---

## Phase 1: AWS CLI Access Preparation

### ✅ Phase 1.1: Configure CLI Profiles

**Create profiles for your Partner Central account:**

```bash
# Option 1: Using IAM Identity Center (SSO) - RECOMMENDED
aws configure sso

# Option 2: Using IAM user credentials (fallback)
cat >> ~/.aws/config <<EOF

[profile partnercentral-admin]
region = us-east-2
output = json
# Add credentials or role_arn as appropriate

[profile partnercentral-ops]
region = us-east-2
output = json
# Add credentials or role_arn as appropriate
EOF
```

**Validation:**
```bash
aws --version
aws sts get-caller-identity --profile partnercentral-admin
aws sts get-caller-identity --profile partnercentral-ops
```

**Checklist:**
- [ ] `partnercentral-admin` profile created (break-glass admin access)
- [ ] `partnercentral-ops` profile created (day-to-day operations)
- [ ] Both profiles validated with `get-caller-identity`

### ✅ Phase 1.2: Account Inventory

**If using AWS Organizations:**
```bash
# Verify account relationship
aws organizations describe-organization

# List all accounts
aws organizations list-accounts

# Confirm your chosen account is a MEMBER (not management)
aws organizations describe-account --account-id <your-partnercentral-account-id>
```

**Checklist:**
- [ ] Account relationship to organization documented
- [ ] Billing structure understood (consolidated billing, etc.)
- [ ] Account is confirmed as member account (if in org)

---

## Phase 2: Baseline Account Security & Audit

### ✅ Phase 2.1: Security Baseline

**Pre-flight checks:**
```bash
# MFA enforcement check
aws iam get-account-summary | jq '.SummaryMap | {AccountMFAEnabled, MFADevices}'

# CloudTrail status
aws cloudtrail describe-trails

# Config status (if used)
aws configservice describe-configuration-recorders
```

**Checklist:**
- [ ] MFA enabled for all admin users
- [ ] CloudTrail logging active (management + data events)
- [ ] AWS Config enabled (optional but recommended)
- [ ] Least-privilege access model documented
- [ ] Admin access path clear (who can do what)

**Deliverable:** "Account Ready" sign-off from IAM Administrator

---

## Phase 3: Verify AWS-Managed Partner Central Policies

### ✅ Phase 3.1: List Available Managed Policies

**Run this to confirm all Partner Central managed policies are available:**

```bash
aws iam list-policies --scope AWS \
  --query "Policies[?starts_with(PolicyName,'AWSPartnerCentral') || starts_with(PolicyName,'PartnerCentral')].[PolicyName,Arn]" \
  --output table
```

**Expected Policies:**
- `AWSPartnerCentralFullAccess` - Full Partner Central access
- `AWSPartnerCentralOpportunityManagement` - Opportunity/deal management
- `AWSPartnerCentralMarketingManagement` - Marketing campaigns
- `AWSPartnerCentralChannelManagement` - Channel partner management
- `AWSPartnerCentralChannelHandshakeApprovalManagement` - Approval workflows
- `PartnerCentralAccountManagementUserRoleAssociation` - Account linking

**Checklist:**
- [ ] All required managed policies confirmed available
- [ ] Policies reviewed for appropriateness to your use case

### ✅ Phase 3.2: Understand Role Naming Requirements

**Critical AWS Requirements:**

1. **Role names MUST start with**: `PartnerCentralRoleFor`
   - ✅ Valid: `PartnerCentralRoleForAllianceLead`
   - ❌ Invalid: `AWSPartnerCentralAccess`, `PartnerCentral-Admin`

2. **Trust policy MUST trust**: `partnercentral-account-management.amazonaws.com`
   - **NOT** an AWS account ARN
   - **NOT** a user or group

**Trust Policy Template:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "partnercentral-account-management.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Checklist:**
- [ ] Role naming convention understood (`PartnerCentralRoleFor*`)
- [ ] Trust policy requirement understood (service principal)
- [ ] Existing roles reviewed (none conflict with new naming)

---

## Phase 4: Create Persona-Based IAM Roles

### ✅ Phase 4.1: Run Automated Role Creation

**Execute the setup script:**

```bash
cd /home/daclab-ai/DEV/AWS-DevOps

# IMPORTANT: Authenticate to your CHOSEN Partner Central account first
export AWS_PROFILE=partnercentral-admin  # or your chosen profile

# Run the modern setup script
./scripts/setup-partner-central-modern.sh
```

**This creates 7 persona-based roles:**

| Role Name | Persona | Managed Policies | Use Case |
|-----------|---------|------------------|----------|
| `PartnerCentralRoleForAllianceLead` | Alliance Lead | `AWSPartnerCentralFullAccess`<br>`AWSMarketplaceSellerFullAccess` | Full Partner Central + Marketplace |
| `PartnerCentralRoleForACEManager` | ACE/Opportunity | `AWSPartnerCentralOpportunityManagement` | Opportunity/deal management |
| `PartnerCentralRoleForMarketing` | Marketing | `AWSPartnerCentralMarketingManagement` | Marketing campaigns |
| `PartnerCentralRoleForChannelManager` | Channel Manager | `AWSPartnerCentralChannelManagement` | Channel partner management |
| `PartnerCentralRoleForChannelApprover` | Channel Approver | `AWSPartnerCentralChannelHandshakeApprovalManagement` | Approval workflows only |
| `PartnerCentralRoleForTechnical` | Technical Staff | `AWSMarketplaceSellerProductsFullAccess` | Marketplace product management |
| `PartnerCentralRoleForReadOnly` | Auditors/Observers | `ReadOnlyAccess` | Read-only access for reporting |

**Checklist:**
- [ ] Script executed successfully
- [ ] All 7 roles created with correct naming
- [ ] Trust policies verified (service principal)
- [ ] Managed policies attached
- [ ] Role ARNs documented

**Verification:**
```bash
# List all Partner Central roles
aws iam list-roles --query "Roles[?starts_with(RoleName,'PartnerCentralRoleFor')].[RoleName,Arn]" --output table

# Verify trust policy for one role
aws iam get-role --role-name PartnerCentralRoleForAllianceLead --query 'Role.AssumeRolePolicyDocument'

# Verify attached policies
aws iam list-attached-role-policies --role-name PartnerCentralRoleForAllianceLead
```

---

## Phase 5: Identity Center / SSO Setup (Optional but Recommended)

### ✅ Phase 5.1: Enable IAM Identity Center

**If not already enabled:**

```bash
# Check if Identity Center is enabled
aws sso-admin list-instances

# If not enabled, you'll need to enable it via AWS Console
# (No CLI command for initial enablement)
```

**AWS Console Steps:**
1. Go to **IAM Identity Center** (formerly AWS SSO)
2. Click **Enable**
3. Choose identity source: AWS Identity Center directory (default) or external IdP
4. Complete setup wizard

**Checklist:**
- [ ] IAM Identity Center enabled
- [ ] Identity source configured
- [ ] Region selected (recommend: us-east-1 or us-east-2)

### ✅ Phase 5.2: Create Permission Sets for Partner Central

**Permission Set Design:**

```
Permission Set Name: PartnerCentral-AllianceLead
  └─ Managed Policies:
      ├─ AWSPartnerCentralFullAccess
      └─ AWSMarketplaceSellerFullAccess

Permission Set Name: PartnerCentral-ACEManager
  └─ Managed Policy: AWSPartnerCentralOpportunityManagement

Permission Set Name: PartnerCentral-Marketing
  └─ Managed Policy: AWSPartnerCentralMarketingManagement

(etc. for each role)
```

**⚠️ Important**: IAM Identity Center has a default limit of **10 managed policies per permission set**. If you need more, request a quota increase.

**Checklist:**
- [ ] Permission sets created for each persona
- [ ] Managed policies attached
- [ ] Groups created and mapped to permission sets
- [ ] Test users assigned to groups

---

## Phase 6: Link Partner Central to AWS Account (THE BIG SWITCH)

### ✅ Phase 6.1: Pre-Flight Checklist

**Before linking, verify:**
- [ ] All IAM roles created with correct prefix/trust
- [ ] IAM Administrator ready to provide account details
- [ ] Alliance Lead has Partner Central admin access
- [ ] Account is on Paid plan (not Free Tier)
- [ ] Billing is current (no outstanding payments)

### ✅ Phase 6.2: Account Linking Process

**Participants:**
- **IAM Administrator**: Provides AWS account ID, confirms IAM access method
- **Alliance Lead**: Completes linking wizard in Partner Central

**Steps (performed by Alliance Lead in Partner Central):**

1. Log into **AWS Partner Central** (https://partnercentral.aws.amazon.com/)
2. Go to **Settings** > **Account Management** (or similar - UI may vary)
3. Click **Link AWS Account**
4. Enter **AWS Account ID**: (your chosen Partner Central account)
5. Select **IAM Access Method**:
   - Option A: IAM Identity Center (SSO) - Recommended
   - Option B: IAM User credentials
6. Click **Verify Account**
   - AWS verifies the IAM roles exist with correct naming/trust
7. Assign **Cloud Admin** role (typically to Alliance Lead)
8. Click **Complete Linking**

**Verification:**
```bash
# From the linked AWS account
aws partnercentral-account describe-account-settings
# (Note: exact command may vary based on AWS CLI version)
```

**Checklist:**
- [ ] Account linking initiated by Alliance Lead
- [ ] AWS account ID provided (_____________________________)
- [ ] IAM access method selected
- [ ] Account verified by AWS
- [ ] Cloud Admin role assigned
- [ ] Linking completed successfully
- [ ] Confirmation email received

---

## Phase 7: User Onboarding & Role Mapping

### ✅ Phase 7.1: Download Current Partner Central Users

**Using the Migration Widget:**

1. In **AWS Partner Central**, navigate to **Migration** or **User Management**
2. Click **Download Users** (migration widget)
3. Export will include:
   - User names
   - Email addresses
   - Current Partner Central roles/permissions
   - Last login dates

**Analysis:**
```bash
# Review downloaded CSV/JSON
# Identify:
# - Active users (logged in recently)
# - Inactive users (can be excluded)
# - Role mappings needed
```

**Checklist:**
- [ ] User list downloaded
- [ ] Active vs inactive users identified
- [ ] Users who need access determined (vs training-only users)
- [ ] Preliminary role mappings documented

### ✅ Phase 7.2: Map Users to IAM Roles

**Mapping Template:**

| Partner Central User | Current Role | Recommended IAM Role | Rationale |
|---------------------|--------------|---------------------|-----------|
| Drew Fortini | Admin | `PartnerCentralRoleForAllianceLead` | Full access + Marketplace |
| ACE Contact 1 | Opportunity Mgr | `PartnerCentralRoleForACEManager` | Opportunity management only |
| Marketing Lead | Marketing | `PartnerCentralRoleForMarketing` | Marketing campaigns |
| Channel Partner 1 | Channel | `PartnerCentralRoleForChannelManager` | Channel partner mgmt |
| Technical Staff 1 | Solutions | `PartnerCentralRoleForTechnical` | Marketplace products |
| ... | ... | ... | ... |

**Mapping Process (in Partner Central Console):**

1. Go to **Settings** > **Manage Linked Account** > **User Mappings**
2. For each user:
   - Select user
   - Choose IAM role (only `PartnerCentralRoleFor*` roles will appear)
   - Save mapping
3. Unmapped users will lose access post-migration

**⚠️ Important**: Only roles with the correct prefix and trust policy will be selectable.

**Checklist:**
- [ ] All active users mapped to appropriate IAM roles
- [ ] Inactive users marked for exclusion
- [ ] Cloud Admin role assigned (required - typically Alliance Lead)
- [ ] Mapping validated (dry-run if available)

**Verification:**
```bash
# Verify role assignments (from Partner Central console)
# - User list shows mapped IAM role ARNs
# - No "unmapped" users remain (unless intentional)
```

---

## Phase 8: Schedule & Execute Migration

### ✅ Phase 8.1: Pre-Migration Checklist

**Final verification before scheduling:**
- [ ] All IAM roles created and verified
- [ ] All users mapped to roles
- [ ] Cloud Admin assigned
- [ ] Migration window selected (non-business hours)
- [ ] Internal communications sent (users will be blocked during migration)
- [ ] ACE/Marketplace operations frozen (no new opportunities/deals during migration)
- [ ] Rollback plan documented (though unlikely to be needed)

### ✅ Phase 8.2: Migration Workflow (4 Steps)

**AWS describes this as a 4-step process:**

**Step 1: Pre-Migration Validation**
- AWS verifies all prerequisites
- Checks IAM roles, user mappings, account status
- Estimated time: 15-30 minutes

**Step 2: Data Migration**
- Migrates opportunities, history, invitations to linked AWS account
- **Users are blocked from accessing Partner Central**
- Estimated time: 1-4 hours (depends on data volume)

**Step 3: IAM Integration**
- Links users to IAM roles
- Tests authentication flows
- Estimated time: 30-60 minutes

**Step 4: Cutover & Validation**
- Switches to new IAM-based access
- Verifies user login
- Sends confirmation
- Estimated time: 15-30 minutes

**Total Duration: 2-6 hours** (AWS estimate)

### ✅ Phase 8.3: Schedule Migration

**In Partner Central:**
1. Go to **Migration** > **Schedule Migration**
2. Select **Migration Window**:
   - Recommended: Non-business hours (e.g., Saturday 2-8 AM)
   - Block off 6-8 hours for safety margin
3. Confirm understanding of:
   - Users will be blocked
   - Duration estimates
   - Cannot be reversed mid-migration
4. Click **Schedule**
5. Receive confirmation with scheduled time

**Checklist:**
- [ ] Migration window scheduled
- [ ] Users notified of downtime
- [ ] Operations frozen (no new opportunities/deals)
- [ ] On-call support identified (in case of issues)
- [ ] AWS Support case opened (optional, for Enterprise Support customers)

### ✅ Phase 8.4: Post-Migration Validation

**Immediately after migration completes:**

```bash
# Test user login (each mapped user)
# 1. Go to AWS Console
# 2. Sign in via IAM Identity Center (or IAM user)
# 3. Navigate to Partner Central in Console
# 4. Verify access to expected features
```

**Validation Checklist:**
- [ ] All mapped users can log in successfully
- [ ] Cloud Admin has full Partner Central access
- [ ] Opportunities visible and accessible
- [ ] Marketplace integration working (if applicable)
- [ ] ACE integration working (if applicable)
- [ ] No unexpected permission errors
- [ ] Confirmation email received from AWS

**If issues:**
1. Check IAM role trust policies
2. Verify user-to-role mappings in Partner Central settings
3. Check CloudTrail for `AssumeRole` denials
4. Contact AWS Partner Central support

---

## Definition-of-Done Checklist (Fast Reference)

### Phase 0: Decision
- [ ] Dedicated Partner Central account chosen (account ID: _____________)
- [ ] Account on Paid plan
- [ ] Not org management/prod/dev account
- [ ] IAM Administrator identified: _____________
- [ ] Alliance Lead identified: _____________

### Phase 1: CLI Access
- [ ] `partnercentral-admin` profile created and tested
- [ ] `partnercentral-ops` profile created and tested
- [ ] Account relationship to org documented

### Phase 2: Security Baseline
- [ ] MFA enabled for admin users
- [ ] CloudTrail active
- [ ] "Account Ready" sign-off from IAM Admin

### Phase 3: Managed Policies
- [ ] All Partner Central managed policies confirmed available
- [ ] Role naming convention understood (`PartnerCentralRoleFor*`)
- [ ] Trust policy requirement understood (service principal)

### Phase 4: IAM Roles
- [ ] 7 persona roles created with correct naming/trust
- [ ] Managed policies attached
- [ ] Role ARNs documented

### Phase 5: Identity Center (Optional)
- [ ] IAM Identity Center enabled
- [ ] Permission sets created
- [ ] Groups/users assigned

### Phase 6: Account Linking
- [ ] Account linked to Partner Central
- [ ] Cloud Admin role assigned
- [ ] Linking confirmation received

### Phase 7: User Mapping
- [ ] Current users downloaded
- [ ] All active users mapped to IAM roles
- [ ] Mappings validated

### Phase 8: Migration
- [ ] Migration window scheduled
- [ ] Users notified
- [ ] Migration completed successfully
- [ ] Post-migration validation passed
- [ ] All users can access Partner Central via IAM

---

## Your Specific Next Steps

Based on your current state:

### ✅ Already Complete
- Organization structure analyzed
- Accounts identified (313476888312, 916873234430, etc.)

### 🔴 Immediate Actions Needed

1. **Decision Required**: Which account will be your Partner Central account?
   - [ ] Create new dedicated account "DiatonicPartnerCentral" (RECOMMENDED)
   - [ ] Use 916873234430 (Diatonic Dev)
   - [ ] Use 313476888312 (Management - NOT recommended)

2. **Run Updated IAM Setup**:
   ```bash
   cd /home/daclab-ai/DEV/AWS-DevOps
   export AWS_PROFILE=<your-chosen-partnercentral-account-profile>
   ./scripts/setup-partner-central-modern.sh
   ```

3. **Download Partner Central Users**:
   - Log into https://partnercentral.aws.amazon.com/
   - Export current user list

4. **Map Users to Roles**:
   - Use mapping template above
   - Assign Drew Fortini to `PartnerCentralRoleForAllianceLead`

5. **Schedule Migration**:
   - Choose non-business hours window
   - Allow 6-8 hours
   - Notify all users

---

## Resources

**AWS Official Documentation:**
- Prerequisites: https://docs.aws.amazon.com/partner-central/latest/getting-started/linking-prerequisites.html
- Managed Policies: https://docs.aws.amazon.com/partner-central/latest/getting-started/managed-policies.html
- User Role Mapping: https://docs.aws.amazon.com/partner-central/latest/getting-started/user-role-mapping.html
- Policy Mappings: https://docs.aws.amazon.com/partner-central/latest/getting-started/managed-policy-mappings.html
- Account Linking: https://docs.aws.amazon.com/partner-central/latest/getting-started/account-linking.html
- Migration Guide: https://docs.aws.amazon.com/partner-central/latest/getting-started/migrating-to-partner-central.html

**Local Scripts:**
- Modern IAM Setup: `/home/daclab-ai/DEV/AWS-DevOps/scripts/setup-partner-central-modern.sh`

**Support:**
- AWS Partner Central Support: https://support.console.aws.amazon.com/support/home
- AWS Partner Network: https://aws.amazon.com/partners/

---

## Estimated Time to Complete

| Phase | Estimated Time | Depends On |
|-------|----------------|------------|
| Phase 0 | 30 min | Decision-making |
| Phase 1-2 | 30 min | CLI setup, security validation |
| Phase 3-4 | 30 min | Role creation (automated script) |
| Phase 5 | 1-2 hours | If enabling Identity Center from scratch |
| Phase 6 | 15 min | Account linking |
| Phase 7 | 1-2 hours | User mapping (depends on user count) |
| Phase 8 | 2-6 hours | Migration execution (AWS-controlled) |
| **TOTAL** | **5-12 hours** | Varies based on org complexity |

**Your Situation:** Estimated **6-8 hours** (you have 9 org accounts, moderate complexity)

---

## Common Issues & Troubleshooting

### Issue: "Role not found in dropdown when mapping users"

**Cause**: Role doesn't meet naming/trust requirements

**Solution**:
```bash
# Verify role naming
aws iam list-roles --query "Roles[?starts_with(RoleName,'PartnerCentralRoleFor')].RoleName"

# Verify trust policy
aws iam get-role --role-name PartnerCentralRoleForAllianceLead \
  --query 'Role.AssumeRolePolicyDocument.Statement[0].Principal.Service'
# Should output: "partnercentral-account-management.amazonaws.com"
```

### Issue: "User can't access Partner Central after migration"

**Cause**: User not mapped to a role OR role lacks required policy

**Solution**:
1. Check user mapping in Partner Central settings
2. Verify role has correct managed policy attached
3. Check CloudTrail for `AssumeRole` denials

### Issue: "Migration failed mid-process"

**Cause**: Rare, but can happen due to data validation issues

**Solution**:
- Contact AWS Support immediately (opened support case recommended before migration)
- Do NOT attempt to manually revert changes
- AWS will provide rollback guidance if needed

---

**Generated**: 2026-01-12
**Last Updated**: 2026-01-12
**Version**: 2.0 (Modern Console Migration Approach)
