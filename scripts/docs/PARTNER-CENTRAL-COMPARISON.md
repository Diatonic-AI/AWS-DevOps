# Partner Central Setup Approaches - Comparison

## Two Different Approaches

You now have documentation for **two different Partner Central setups**:

### Approach 1: Legacy/API-Based (My Initial Setup)
**Files:** `PARTNER-CENTRAL-SETUP.md`, `setup-partner-central-iam.sh`

**What it does:**
- Creates IAM roles for AWS Partner Central **API/service** access
- Uses account-based trust (account 905418367684)
- Generic role names (`AWSPartnerCentralAccess`, etc.)
- Focused on **Partner Central web portal** (partnercentral.aws.amazon.com)
- Good for immediate API integration

**When to use:**
- You need quick Partner Central API access
- You're not migrating to Partner Central in AWS Console yet
- You want to complete the 17 tasks in the web portal

---

### Approach 2: Modern Console Migration (Your Plan + My Updated Script)
**Files:** `PARTNER-CENTRAL-CONSOLE-MIGRATION.md`, `setup-partner-central-modern.sh`

**What it does:**
- Creates IAM roles for **Partner Central in AWS Console**
- Uses service principal trust (`partnercentral-account-management.amazonaws.com`)
- Required prefix naming (`PartnerCentralRoleFor*`)
- Focused on **IAM-based user access** via AWS Console
- Migration-ready for Partner Central Console

**When to use:**
- You're migrating to Partner Central in AWS Console
- You want IAM Identity Center / SSO integration
- You need proper user-to-role mapping for team access
- AWS has notified you to migrate (or you want the modern approach)

---

## Side-by-Side Comparison

| Feature | Legacy/API Approach | Modern Console Approach |
|---------|---------------------|-------------------------|
| **Target Platform** | Partner Central Web Portal | Partner Central in AWS Console |
| **IAM Role Naming** | Generic names allowed | **MUST** start with `PartnerCentralRoleFor` |
| **Trust Policy** | AWS account 905418367684 | Service: `partnercentral-account-management.amazonaws.com` |
| **User Access** | Direct web login | IAM/SSO-based console access |
| **Migration Ready** | No | Yes (migration-ready) |
| **Account Strategy** | Any account (including org mgmt) | **Dedicated member account required** |
| **User Mapping** | Not applicable | User-to-role mapping required |
| **Setup Complexity** | Simple (3 roles) | More complex (7+ persona roles) |
| **AWS Recommendation** | Legacy (being phased out) | **Current AWS best practice** |

---

## Which Approach Should You Use?

### Use **Approach 1 (Legacy)** if:
- ✅ You just need to complete the 17 Partner Central tasks quickly
- ✅ You're not ready for full AWS Console migration
- ✅ You want immediate access to Partner Central web portal
- ✅ Your team uses the existing partnercentral.aws.amazon.com portal
- ⏰ Timeline: Complete tasks in 4-6 hours

### Use **Approach 2 (Modern)** if:
- ✅ AWS has notified you to migrate to Console
- ✅ You want IAM Identity Center / SSO integration
- ✅ You have multiple team members needing different access levels
- ✅ You're building a **long-term Partner Central strategy**
- ✅ You want to follow AWS's current recommendations
- ⏰ Timeline: 6-12 hours (includes migration planning)

### Use **BOTH** approaches if:
- ✅ Complete Approach 1 first (immediate access to complete tasks)
- ✅ Then do Approach 2 when AWS announces migration deadline
- ⏰ Timeline: Approach 1 now, Approach 2 in 3-6 months

---

## Recommendation for Your Situation

Based on your current state:

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  RECOMMENDED PATH: Hybrid Approach                         │
│                                                             │
│  1. Use Approach 1 (DONE ✓) to complete 17 tasks          │
│     - Roles already created                                │
│     - Go to Partner Central web portal                     │
│     - Complete tasks 1-17                                  │
│                                                             │
│  2. Create dedicated Partner Central account (NEW)         │
│     - Don't use 313476888312 (management)                 │
│     - Create "DiatonicPartnerCentral" account             │
│                                                             │
│  3. When ready for Console Migration:                      │
│     - Run Approach 2 setup in new dedicated account       │
│     - Map users to roles                                  │
│     - Schedule migration                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Why this path?**
1. **Speed**: Approach 1 is already done - use it to complete tasks now
2. **Compliance**: Approach 2 sets you up for future AWS requirements
3. **Safety**: Dedicated account separates Partner Central from production
4. **Flexibility**: Migrate when YOU'RE ready, not under pressure

---

## Migration Timeline Expectations

AWS is gradually moving all partners to Console-based Partner Central:

```
Now (2026-Q1):
  ├─ Both approaches work
  ├─ Web portal still fully functional
  └─ Console migration optional but recommended

Future (2026-Q2/Q3):
  ├─ AWS will start sending migration notices
  ├─ Web portal may have reduced features
  └─ Console migration becomes required

Long-term (2026-Q4+):
  ├─ Web portal deprecated
  ├─ Console is the only option
  └─ IAM-based access mandatory
```

**Implication**: You have time to use Approach 1 now, but should plan for Approach 2 within 6-12 months.

---

## What to Do RIGHT NOW

### Option A: Complete Legacy Tasks First (FASTEST)
```bash
# 1. Use existing roles (already created)
# Roles:
#   - arn:aws:iam::313476888312:role/AWSPartnerCentralAccess
#   - arn:aws:iam::313476888312:role/AWSPartnerACEAccess
#   - arn:aws:iam::313476888312:role/AWSPartnerAllianceAccess

# 2. Go to Partner Central web portal
open https://partnercentral.aws.amazon.com/

# 3. Complete the 17 tasks using your existing setup
# Reference: PARTNER-CENTRAL-SETUP.md

# 4. Plan for Console migration later (3-6 months)
```

**Pros:**
- ✅ Fastest path to task completion
- ✅ Uses work already done
- ✅ Gets you Partner Central access immediately

**Cons:**
- ⚠️ Will need to migrate later anyway
- ⚠️ Using management account (not ideal)

---

### Option B: Start Fresh with Modern Approach (PROPER)
```bash
# 1. Create dedicated Partner Central account
aws organizations create-account \
  --email aws+partner-central@dacvisuals.com \
  --account-name "DiatonicPartnerCentral"

# Wait for account creation (5-10 minutes)

# 2. Set up IAM access to new account
# Add to ~/.aws/config:
[profile partnercentral-admin]
role_arn = arn:aws:iam::<NEW-ACCOUNT-ID>:role/OrganizationAccountAccessRole
source_profile = dfortini-local
region = us-east-2

# 3. Run modern setup
export AWS_PROFILE=partnercentral-admin
./scripts/setup-partner-central-modern.sh

# 4. Link account and map users
# (See PARTNER-CENTRAL-CONSOLE-MIGRATION.md)

# 5. Schedule migration
```

**Pros:**
- ✅ Proper dedicated account architecture
- ✅ Future-proof (migration-ready)
- ✅ Follows AWS best practices

**Cons:**
- ⏰ Takes longer (6-12 hours total)
- 📋 More complex setup
- 🔄 Requires user mapping and migration

---

## Comparison of Your Options

| Criteria | Option A: Legacy First | Option B: Modern First |
|----------|----------------------|----------------------|
| **Time to Complete Tasks** | 4-6 hours | 8-14 hours |
| **Account Used** | 313476888312 (management) ⚠️ | New dedicated account ✅ |
| **Future Migration Needed** | Yes (in 3-6 months) | No (already migrated) |
| **AWS Best Practice** | No | Yes |
| **Complexity** | Low | Medium-High |
| **IAM Roles** | 3 generic roles | 7 persona roles |
| **Team Access** | Manual | SSO/IAM-based |
| **Recommended For** | Quick task completion | Long-term strategy |

---

## My Recommendation

**Do Option A NOW, Option B LATER:**

### Phase 1 (This Week): Complete Tasks with Approach 1
1. ✅ Use roles I already created
2. ✅ Go to partnercentral.aws.amazon.com
3. ✅ Complete all 17 tasks
4. ✅ Get Partner Central fully functional

**Effort**: 4-6 hours
**Deliverable**: Active Partner Central account, tasks complete

### Phase 2 (Next 1-3 Months): Plan Modern Migration
1. Create dedicated Partner Central account
2. Set up IAM Identity Center (if not already)
3. Document user-to-role mappings
4. Test roles in new dedicated account

**Effort**: 2-3 hours planning
**Deliverable**: Migration-ready plan

### Phase 3 (When AWS Announces Migration): Execute Migration
1. Run `setup-partner-central-modern.sh` in dedicated account
2. Link dedicated account to Partner Central
3. Map all users to roles
4. Schedule and execute migration

**Effort**: 4-6 hours execution
**Deliverable**: Fully migrated to Console

---

## Files Reference

### Approach 1 (Legacy) Files:
- **Setup Guide**: `docs/PARTNER-CENTRAL-SETUP.md`
- **Config Reference**: `partner-central-config.txt`
- **Quick Start**: `QUICK-START-PARTNER-CENTRAL.md`
- **IAM Script**: `scripts/setup-partner-central-iam.sh` (already run ✅)
- **Task Tracker**: `scripts/partner-tasks-tracker.sh`

### Approach 2 (Modern) Files:
- **Migration Guide**: `docs/PARTNER-CENTRAL-CONSOLE-MIGRATION.md` ⭐ NEW
- **Modern IAM Script**: `scripts/setup-partner-central-modern.sh` ⭐ NEW

### Both Approaches:
- **Builder Account**: `scripts/connect-builder-account.sh`
- **Troubleshooting**: `scripts/create-builder-account-role.sh`

---

## Summary Decision Tree

```
Do you need Partner Central access TODAY?
├─ YES → Use Approach 1 (legacy)
│         Complete 17 tasks this week
│         Plan migration for later
│
└─ NO → Use Approach 2 (modern)
          Set up properly from the start
          Avoid migration later

Has AWS sent you a migration deadline?
├─ YES → MUST use Approach 2
│         Migration is mandatory
│
└─ NO → You have flexibility
          Can use Approach 1 now
          Migrate when ready

Do you have a dedicated Partner Central account?
├─ YES → Run setup-partner-central-modern.sh
│
└─ NO → Two options:
          1. Use management account (Approach 1) - faster but not ideal
          2. Create dedicated account (Approach 2) - proper but slower
```

---

## Questions to Help You Decide

**Ask yourself:**

1. **When do I need Partner Central access?**
   - Today/this week → Approach 1
   - Can wait 1-2 weeks → Approach 2

2. **Has AWS notified me to migrate?**
   - Yes → Approach 2 (required)
   - No → Either approach works

3. **How many team members need access?**
   - Just me (1-2 people) → Approach 1 is fine
   - Team of 5+ → Approach 2 better for user management

4. **Do I want to set this up once or twice?**
   - Once (do it right) → Approach 2
   - Twice (fast now, proper later) → Approach 1 then 2

5. **Do I have a dedicated Partner Central account?**
   - Yes → Approach 2
   - No (and don't want to create one yet) → Approach 1

---

## Final Recommendation

**FOR YOU SPECIFICALLY:**

```
✅ STEP 1 (NOW): Use Approach 1 to complete the 17 tasks
   - Roles already created in 313476888312
   - Go to https://partnercentral.aws.amazon.com/
   - Map Alliance Team, ACE users, assign roles
   - Build your first solution (AI Nexus Workbench)
   - Pay APN fee, create opportunities
   - Estimated time: 4-6 hours

✅ STEP 2 (NEXT MONTH): Create dedicated Partner Central account
   - Create new account "DiatonicPartnerCentral"
   - Set up OrganizationAccountAccessRole
   - Test CLI access
   - Estimated time: 1 hour

✅ STEP 3 (WHEN READY): Migrate to Console
   - Run setup-partner-central-modern.sh in new account
   - Map users to persona roles
   - Schedule migration (non-business hours)
   - Estimated time: 6-8 hours

TOTAL EFFORT: 11-15 hours spread over 1-3 months
```

**Why this path?**
- Gets you operational immediately (Approach 1)
- Positions you for future migration (Approach 2 prep)
- Minimizes disruption (migration when YOU choose)
- Follows AWS best practices (eventually)

---

**Generated**: 2026-01-12
**Comparison**: Legacy API vs Modern Console Migration
**Recommendation**: Hybrid approach (do both, staged)
