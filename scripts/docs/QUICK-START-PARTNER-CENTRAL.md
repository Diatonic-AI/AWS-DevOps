# AWS Partner Central Quick Start Guide

## ✅ What's Been Completed

Your AWS Partner Central setup is **partially complete**:

### Automated Setup (DONE ✓)
1. **IAM Roles Created** in management account (313476888312):
   - `AWSPartnerCentralAccess` - Main integration role
   - `AWSPartnerACEAccess` - ACE user access
   - `AWSPartnerAllianceAccess` - Alliance team access

2. **AWS CLI Profiles Configured**:
   - `partner-builder` profile created for builder account access
   - Management account authenticated as `dfortini-local`

3. **Documentation Generated**:
   - Complete setup guide
   - Configuration file
   - Helper scripts

### Status: 1 of 17 tasks complete (6%)

---

## 🎯 Your Next Steps (In Priority Order)

### STEP 1: Complete IAM Role Mapping (15 minutes)

Go to [AWS Partner Central](https://partnercentral.aws.amazon.com/) and complete these HIGH PRIORITY tasks:

#### Task 3: Map Alliance Team to IAM Roles (<30 min)
```
1. Settings > Team Management > Alliance Team
2. Click "Add IAM Role"
3. Enter: arn:aws:iam::313476888312:role/AWSPartnerAllianceAccess
4. Save
```

#### Task 4: Map ACE Users to IAM Roles (<5 min)
```
1. Settings > Team Management > ACE Users
2. Click "Add IAM Role"
3. Enter: arn:aws:iam::313476888312:role/AWSPartnerACEAccess
4. Save
```

#### Task 5: Assign User Role (<5 min)
```
1. Settings > Users
2. Find Drew Fortini
3. Assign: "Account Administrator" or "Solution Manager"
4. Save
```

#### Task 15: Assign Cloud Admin (<5 min)
```
1. Settings > Team Management
2. Click "Assign Cloud Admin"
3. Select: Drew Fortini
4. Confirm
```

#### Task 12: Invite Users (<5 min)
```
1. Settings > Users > Invite User
2. Add team member emails
3. Assign appropriate roles
4. Send invitations
```

### STEP 2: Register Builder Account (5 minutes)

```
1. Log into Partner Central
2. Settings > AWS Accounts > Add Account
3. Enter:
   - Account ID: 916873234430
   - Account Alias: diatonic-dev-builder
   - Account Type: Builder Account
4. Click "Verify Account"
5. Save
```

### STEP 3: Pay APN Membership Fee (30 minutes)

**RECOMMENDED: Select Tier - $2,500/year**

Benefits:
- AWS Marketplace eligibility
- Co-marketing support
- Partner training and enablement
- Qualified leads from AWS

```
1. Settings > Membership
2. Select tier: "Select" ($2,500/year)
3. Click "Upgrade"
4. Enter payment information
5. Complete payment
```

### STEP 4: Build Your First Software Solution (1-2 hours)

**RECOMMENDATION: Showcase "Diatonic AI Nexus Workbench"**

Your repository already contains the perfect solution:

#### What You Have:
- **Application**: `apps/diatonic-ai-workbench/` (AI/ML workbench application)
- **Infrastructure**: `infrastructure/terraform/core/` (ECR, Lambda, API Gateway, DynamoDB, Cognito)
- **Containers**: Docker configurations for deployment

#### Solution Details to Enter:
```
Name: Diatonic AI Nexus Workbench
Category: AI/ML, Container Management
AWS Services:
  - Amazon ECR (Container Registry)
  - Amazon ECS/Fargate (Container Orchestration)
  - AWS Lambda (Serverless Functions)
  - Amazon API Gateway (API Management)
  - Amazon DynamoDB (NoSQL Database)
  - Amazon Cognito (Authentication)
  - Amazon S3 (File Storage)

Builder Account: 916873234430 (Diatonic Dev)

Description:
  A comprehensive AI/ML workbench platform built on AWS serverless
  technologies. Provides secure, scalable infrastructure for AI model
  development, training, and deployment with integrated authentication
  and data management.
```

#### Materials to Upload:
1. **Architecture Diagram**: Create a visual diagram showing:
   - User → CloudFront/API Gateway
   - API Gateway → Lambda functions
   - Lambda → DynamoDB, S3
   - ECS/Fargate for container workloads
   - Cognito for authentication

2. **CloudFormation/Terraform Templates**:
   - Use your existing files from `infrastructure/terraform/core/`
   - Include: ECR, Lambda, API Gateway, DynamoDB, Cognito configs

3. **README/Deployment Guide**:
   - Setup instructions
   - Prerequisites
   - Deployment steps
   - Configuration options

4. **Security Documentation**:
   - IAM roles and policies
   - Network security
   - Data encryption

---

## 📊 Task Progress Tracker

Use the interactive task tracker:

```bash
# View all tasks
./scripts/partner-tasks-tracker.sh

# View high priority tasks only
./scripts/partner-tasks-tracker.sh high

# Mark a task as complete
./scripts/partner-tasks-tracker.sh complete 3

# Get help for a specific task
./scripts/partner-tasks-tracker.sh details 14
```

---

## 🔑 Key Information

### Your AWS Accounts

| Account | ID | Purpose |
|---------|-----|---------|
| **Management** | 313476888312 | IAM roles, billing, Partner Central integration |
| **Builder** | 916873234430 | Deploy and test solutions |

### IAM Role ARNs (For Partner Central)

```
Partner Central Access:
arn:aws:iam::313476888312:role/AWSPartnerCentralAccess

ACE User Access:
arn:aws:iam::313476888312:role/AWSPartnerACEAccess

Alliance Team Access:
arn:aws:iam::313476888312:role/AWSPartnerAllianceAccess
```

### AWS CLI - Switch to Builder Account

```bash
# Option 1: Use profile
export AWS_PROFILE=partner-builder
aws sts get-caller-identity

# Option 2: Assume role manually
aws sts assume-role \
  --role-arn arn:aws:iam::916873234430:role/OrganizationAccountAccessRole \
  --role-session-name partner-builder
```

**Note**: If you get "AccessDenied", you need to create the OrganizationAccountAccessRole in the builder account. See troubleshooting section.

---

## 📁 Files Created

All documentation and scripts are in `/home/daclab-ai/DEV/AWS-DevOps/`:

| File | Purpose |
|------|---------|
| `partner-central-config.txt` | Complete configuration reference |
| `docs/PARTNER-CENTRAL-SETUP.md` | Detailed setup guide (all 17 tasks) |
| `scripts/setup-partner-central-iam.sh` | IAM role creation script ✓ EXECUTED |
| `scripts/connect-builder-account.sh` | Builder account setup |
| `scripts/create-builder-account-role.sh` | Fix builder account access |
| `scripts/partner-central-quickstart.sh` | Complete automated setup |
| `scripts/partner-tasks-tracker.sh` | Interactive task tracker |

---

## 🏗️ Your Existing Infrastructure

You already have production-ready infrastructure that's perfect for Partner Central:

### AI Nexus Workbench
```
apps/diatonic-ai-workbench/         # Main application (submodule)
infrastructure/terraform/core/       # Infrastructure as Code
  ├── app-ainexus-ecr.tf            # Container registry
  ├── api-gateway-ainexus.tf        # API Gateway setup
  ├── lambda-ainexus.tf             # Lambda functions
  ├── dynamodb-ainexus.tf           # DynamoDB tables
  ├── cognito-ainexus.tf            # Authentication
  └── s3-ainexus-uploads.tf         # File storage
```

This is **exactly** the kind of solution AWS Partner Central wants to see!

---

## ⏱️ Time Estimates

| Phase | Time | Status |
|-------|------|--------|
| Automated Setup | 30 min | ✅ Complete |
| IAM Role Mapping | 15 min | 🔴 High Priority |
| Builder Account Setup | 5 min | 🟡 Pending |
| APN Fee Payment | 30 min | 🟡 Pending |
| Solution Building | 1-2 hrs | 🟡 Pending |
| Remaining Tasks | 1-2 hrs | 🟢 Low Priority |
| **TOTAL** | **4-6 hrs** | **6% Complete** |

---

## 🚨 Troubleshooting

### Cannot Access Builder Account

**Error**: `AccessDenied` when using `partner-builder` profile

**Solution**: Create the OrganizationAccountAccessRole in the builder account

1. Log into AWS Console as root for account 916873234430
2. Go to IAM > Roles > Create Role
3. Trusted entity: AWS Account
4. Account ID: 313476888312
5. Role name: `OrganizationAccountAccessRole`
6. Attach policy: `AdministratorAccess`
7. Create role

### Partner Central Can't Verify Account

**Checklist**:
- ✓ IAM roles are in MANAGEMENT account (313476888312), not builder
- ✓ Trust policy allows account 905418367684 (AWS Partner Central)
- ✓ External ID is set to "PartnerCentral"
- ✓ Roles have required permissions

Verify:
```bash
aws iam get-role --role-name AWSPartnerCentralAccess
aws iam list-attached-role-policies --role-name AWSPartnerCentralAccess
```

---

## 🎓 Learning Resources

### For Task 14 (Build Software Solution)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Reference Architectures](https://aws.amazon.com/architecture/)
- [Container Reference Architecture](https://github.com/aws-samples/ecs-refarch-continuous-deployment)

### For Task 16 (AWS Marketplace)
- [AWS Marketplace Seller Guide](https://docs.aws.amazon.com/marketplace/latest/userguide/)
- [Container Products on AWS Marketplace](https://docs.aws.amazon.com/marketplace/latest/userguide/container-products.html)
- [Pricing Models](https://docs.aws.amazon.com/marketplace/latest/userguide/pricing.html)

---

## 🔗 Important Links

- **Partner Central Portal**: https://partnercentral.aws.amazon.com/
- **AWS Marketplace Management**: https://aws.amazon.com/marketplace/management/
- **APN Programs**: https://aws.amazon.com/partners/programs/
- **Support**: https://support.console.aws.amazon.com/support/home

---

## ✨ What Makes Your Solution Stand Out

Your **Diatonic AI Nexus Workbench** is an excellent Partner Central solution because:

1. **Modern Architecture**: Serverless, containerized, scalable
2. **Multiple AWS Services**: ECR, Lambda, API Gateway, DynamoDB, Cognito, S3
3. **Well-Architected**: Security, reliability, performance, cost optimization
4. **Production-Ready**: Already deployed and tested infrastructure
5. **IaC Foundation**: Terraform configuration for repeatable deployments
6. **AI/ML Focus**: High-demand category in AWS Partner ecosystem

---

## 📝 Next Session Checklist

When you're ready to complete the tasks:

1. ✅ Open Partner Central: https://partnercentral.aws.amazon.com/
2. ✅ Have IAM role ARNs ready (see "Key Information" above)
3. ✅ Set aside 4-6 hours for focused work
4. ✅ Have payment method ready for APN fee ($2,500)
5. ✅ Review your AI Nexus Workbench infrastructure
6. ✅ Prepare architecture diagram for solution submission

---

## 💡 Tips for Success

1. **Start with HIGH priority tasks** - They unlock other features
2. **Select Tier APN membership** - Best value for your situation
3. **Use your existing infrastructure** - Don't rebuild from scratch
4. **Document well** - Good documentation helps AWS verify your solution
5. **Track progress** - Use the task tracker script
6. **Ask for help** - AWS Partner Central support is available

---

## Summary

You've completed the **technical foundation** for AWS Partner Central:
- ✅ IAM roles created and configured
- ✅ Builder account profile set up
- ✅ Complete documentation and tools ready

**Next**: Complete the web UI tasks in Partner Central (15-30 minutes), then build your first solution showcase using your existing AI Nexus Workbench infrastructure.

**Estimated time to 100% completion**: 4-6 hours of focused work

Good luck! 🚀
