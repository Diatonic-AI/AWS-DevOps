# AWS Partner Central Setup Guide

## Overview

This guide walks you through completing all 17 AWS Partner Central tasks and connecting your builder account.

## Current AWS Configuration

- **Master Account**: 313476888312 (DiatonicAI)
- **Builder Account**: 916873234430 (Diatonic Dev)
- **Organization ID**: o-eyf5fcwrr3
- **Current User**: dfortini-local (IAM User)

## Prerequisites

```bash
# Verify you're authenticated
aws sts get-caller-identity

# Should show:
# Account: 313476888312
# User: dfortini-local
```

## Task Completion Checklist

### Phase 1: IAM Role Setup (Required for Partner Central)

#### Task 6: Create IAM Roles ⏱️ <30 minutes

**Run the automated setup script:**

```bash
cd /home/daclab-ai/DEV/AWS-DevOps
chmod +x scripts/setup-partner-central-iam.sh
./scripts/setup-partner-central-iam.sh
```

**What this creates:**
1. `AWSPartnerCentralAccess` - Main Partner Central integration role
2. `AWSPartnerACEAccess` - Role for AWS ACE (AWS Customer Engagement) users
3. `AWSPartnerAllianceAccess` - Role for AWS Alliance team members

**Manual verification:**

```bash
# List the created roles
aws iam list-roles --query 'Roles[?contains(RoleName, `Partner`)].RoleName'

# Get role ARNs (save these for Partner Central)
aws iam get-role --role-name AWSPartnerCentralAccess --query 'Role.Arn' --output text
aws iam get-role --role-name AWSPartnerACEAccess --query 'Role.Arn' --output text
aws iam get-role --role-name AWSPartnerAllianceAccess --query 'Role.Arn' --output text
```

#### Task 3: Map Alliance Team to IAM Roles ⏱️ <30 minutes

1. Go to [AWS Partner Central](https://partnercentral.aws.amazon.com/)
2. Navigate to **Settings** > **Team Management** > **Alliance Team**
3. Click **Add IAM Role**
4. Enter the ARN for `AWSPartnerAllianceAccess` (from above)
5. Click **Save**

#### Task 4: Map ACE Users to IAM Roles ⏱️ <5 minutes

1. In Partner Central, go to **Settings** > **Team Management** > **ACE Users**
2. Click **Add IAM Role**
3. Enter the ARN for `AWSPartnerACEAccess`
4. Click **Save**

#### Task 5: Assign User Role ⏱️ <5 minutes

1. In Partner Central, go to **Settings** > **Users**
2. Find your user (Drew Fortini)
3. Click **Edit**
4. Assign role: **Account Administrator** or **Solution Manager**
5. Click **Save**

#### Task 15: Assign a Cloud Admin ⏱️ <5 minutes

1. In Partner Central, go to **Settings** > **Team Management**
2. Click **Assign Cloud Admin**
3. Select Drew Fortini (or appropriate team member)
4. Verify IAM permissions in account 313476888312
5. Click **Confirm**

#### Task 12: Invite Users to Join AWS Partner Central ⏱️ <5 minutes

1. In Partner Central, go to **Settings** > **Users**
2. Click **Invite User**
3. Enter email addresses for team members
4. Assign appropriate roles:
   - **Account Administrator**: Full access
   - **Solution Manager**: Build and submit solutions
   - **Marketing User**: Marketing materials and campaigns
   - **Sales User**: Opportunity management
5. Click **Send Invitations**

### Phase 2: Account Migration & Setup

#### Task 1: Schedule Migration to Partner Central in AWS Console ⏱️ <4 hours

**Background**: AWS is migrating Partner Central to be directly accessible through the AWS Console.

1. Log into [AWS Partner Central](https://partnercentral.aws.amazon.com/)
2. Look for migration banner/notification at the top
3. Click **Schedule Migration**
4. Select a maintenance window (suggest off-hours)
5. Review migration checklist:
   - IAM roles are configured ✓
   - Users are mapped ✓
   - Solutions are documented
6. Click **Confirm Migration Schedule**

**Note**: This is mostly automated. The 4-hour estimate includes AWS processing time.

### Phase 3: Solution Development

#### Task 14: Build Your First Software Solution ⏱️ >30 minutes

**Builder Account Setup:**

Your designated builder account is **916873234430 (Diatonic Dev)**.

**Switch to builder account:**

```bash
# Using AWS CLI
export AWS_PROFILE=online-824  # or create new profile for builder account

# Or using assume-role
aws sts assume-role \
  --role-arn arn:aws:iam::916873234430:role/OrganizationAccountAccessRole \
  --role-session-name partner-builder-session
```

**Solution Requirements:**

For a software solution, you need to demonstrate:

1. **Architecture**: CloudFormation or Terraform templates
2. **Documentation**: README, deployment guide
3. **Security**: IAM roles, security groups properly configured
4. **Scalability**: Auto-scaling or load balancing
5. **Monitoring**: CloudWatch dashboards and alarms

**Example Software Solutions:**

Based on your codebase, you could showcase:

- **AI Nexus Workbench** (apps/diatonic-ai-workbench)
  - Container-based AI/ML platform
  - ECR integration
  - ECS/Fargate deployment

**Create solution in Partner Central:**

1. Go to **Solutions** > **Create Solution**
2. Select **Software Solution**
3. Fill in details:
   - **Solution Name**: "Diatonic AI Nexus Workbench"
   - **Category**: AI/ML, Container Management
   - **AWS Services Used**: ECR, ECS, Lambda, API Gateway, DynamoDB
   - **Builder Account**: 916873234430
4. Upload architecture diagrams
5. Link to CloudFormation templates
6. Click **Submit for Review**

#### Task 17: Build Your Services Solution ⏱️ <10 minutes

1. In Partner Central, go to **Solutions** > **Create Solution**
2. Select **Consulting Services**
3. Fill in service details:
   - **Service Type**: Consulting, Managed Services, Professional Services
   - **Service Categories**: Cloud Migration, DevOps, AI/ML
   - **Delivery Model**: Remote, On-site, Hybrid
4. Describe your service offerings
5. Add case studies/testimonials if available
6. Click **Submit**

#### Task 9: Build Your Managed Services Solution ⏱️ <10 minutes

1. In Partner Central, go to **Solutions** > **Create Solution**
2. Select **Managed Services**
3. Define your managed service offering:
   - **Service Name**: "AWS Infrastructure Management"
   - **Description**: 24/7 monitoring, security, optimization
   - **AWS Services Managed**: EC2, RDS, S3, Lambda, etc.
   - **SLA**: Define uptime guarantees
   - **Pricing Model**: Per-resource, per-hour, monthly retainer
4. Upload service documentation
5. Click **Submit**

### Phase 4: Marketing & Marketplace

#### Task 7: Create AWS Marketplace Listing ⏱️ 5 minutes

1. Go to [AWS Marketplace Management Portal](https://aws.amazon.com/marketplace/management/)
2. Click **Get Started** or **Create New Product**
3. Select product type:
   - **AMI**: If you have a pre-built image
   - **Container**: For container-based solutions (recommended for your AI workbench)
   - **SaaS**: For hosted services
4. Fill in product details
5. Set pricing model
6. Click **Save Draft**

**For Container-based product:**

```bash
# Tag your AI Nexus Workbench image for Marketplace
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin <your-ecr-registry>

docker tag diatonic-ai-workbench:latest <marketplace-ecr>:latest
docker push <marketplace-ecr>:latest
```

#### Task 16: Learn About AWS Marketplace Benefits and Pricing ⏱️ <30 minutes

**Self-paced learning:**

1. Visit [AWS Marketplace Seller Guide](https://docs.aws.amazon.com/marketplace/latest/userguide/)
2. Review pricing models:
   - **Free**: Good for freemium or open-source
   - **BYOL** (Bring Your Own License): Customer has existing license
   - **Usage-based**: Pay per hour/instance
   - **Contract**: Annual/multi-year agreements
   - **SaaS Subscriptions**: Monthly subscriptions
3. Understand AWS Marketplace fees:
   - AWS takes **3-15%** depending on product type
   - SaaS products: 3%
   - AMI/Container products: 15%

### Phase 5: Opportunity Management

#### Task 2: Create Your First Partner Originated (PO) Opportunity ⏱️ >30 minutes

1. In Partner Central, go to **Opportunities** > **Create Opportunity**
2. Select **Partner Originated (PO)**
3. Fill in opportunity details:
   - **Customer Name**: (Your client)
   - **Opportunity Name**: Descriptive name
   - **AWS Account ID**: Customer's AWS account (if known)
   - **Expected Monthly Recurring Revenue (MRR)**
   - **Close Date**: Estimated deal closure
   - **AWS Products**: Services you'll use
   - **Solution**: Link to your solution from Task 14/17
4. Add notes on customer requirements
5. Click **Submit**

**Benefits of registering opportunities:**
- Protects your deal (prevents AWS from working directly with customer)
- Eligible for AWS co-selling and funding
- Access to AWS Partner Solutions Architects
- Potential for AWS Marketplace Private Offers

### Phase 6: Company Profile

#### Task 10: Update Company Profile - Technology Team Size ⏱️ <5 minutes

1. In Partner Central, go to **Settings** > **Company Profile**
2. Scroll to **Team Information**
3. Enter **Technology Team Size**: (e.g., 1-10, 11-50)
4. Click **Save**

#### Task 11: Update Company Profile - Marketing Team Size ⏱️ <5 minutes

1. Same section as above
2. Enter **Marketing Team Size**
3. Click **Save**

#### Task 13: Update Company Profile - Sales Team Size ⏱️ <5 minutes

1. Same section as above
2. Enter **Sales Team Size**
3. Click **Save**

### Phase 7: Financial

#### Task 8: Pay APN Fee ⏱️ >30 minutes

**APN Membership Tiers:**

1. **Registered** (Free): Basic access, limited benefits
2. **Select** ($2,500/year): Enhanced benefits, co-marketing
3. **Advanced** ($15,000/year): Full benefits, AWS funding eligibility

**To pay:**

1. In Partner Central, go to **Settings** > **Membership**
2. Select desired tier
3. Click **Upgrade**
4. Enter payment information (credit card or AWS account billing)
5. Review and confirm
6. Click **Complete Payment**

**Recommendation**: Start with **Select tier** ($2,500) for:
- AWS Marketplace eligibility
- Co-marketing support
- Partner training and enablement
- Qualified leads from AWS

## Builder Account Connection Guide

### Understanding Builder vs. Management Accounts

**Management Account (313476888312 - DiatonicAI)**:
- AWS Organization master account
- Billing and account management
- Should host Partner Central IAM roles

**Builder Account (916873234430 - Diatonic Dev)**:
- Where you deploy and test solutions
- Where Partner Central will verify your solution architecture
- Should contain your reference implementations

### Connecting Builder Account

**Option 1: AWS CLI Profile (Recommended)**

```bash
# Create profile for builder account
cat >> ~/.aws/config <<EOF

[profile partner-builder]
role_arn = arn:aws:iam::916873234430:role/OrganizationAccountAccessRole
source_profile = dfortini-local
region = us-east-2
output = json
EOF

# Test the connection
aws sts get-caller-identity --profile partner-builder

# Set as default for current session
export AWS_PROFILE=partner-builder
```

**Option 2: Assume Role Manually**

```bash
# Get temporary credentials
aws sts assume-role \
  --role-arn arn:aws:iam::916873234430:role/OrganizationAccountAccessRole \
  --role-session-name partner-builder-session \
  --duration-seconds 3600

# Extract credentials from output and set as environment variables
export AWS_ACCESS_KEY_ID="<AccessKeyId from output>"
export AWS_SECRET_ACCESS_KEY="<SecretAccessKey from output>"
export AWS_SESSION_TOKEN="<SessionToken from output>"
```

**Option 3: Use Existing Profile**

You already have a profile configured:

```bash
# Use the existing profile
export AWS_PROFILE=online-824  # This assumes role into 824156498500 (Diatonic Online)

# Or for account 842990485193 (Diatonic AI):
export AWS_PROFILE=mgmt-842
```

**Note**: You may want to create a dedicated profile for the Diatonic Dev account (916873234430).

### Verify Builder Account Access

```bash
# Switch to builder account
export AWS_PROFILE=partner-builder  # or whichever profile you set up

# Verify identity
aws sts get-caller-identity

# Should show account: 916873234430

# List resources in builder account
aws ec2 describe-instances
aws lambda list-functions
aws ecs list-clusters
aws ecr describe-repositories
```

### Register Builder Account in Partner Central

1. Log into Partner Central
2. Go to **Settings** > **AWS Accounts**
3. Click **Add Account**
4. Enter **Account ID**: `916873234430`
5. Enter **Account Alias**: `diatonic-dev-builder`
6. Select **Account Type**: **Builder Account**
7. Click **Verify Account**
8. AWS will verify you have the necessary IAM roles in the management account
9. Click **Save**

## Quick Start Script

Run this to set up everything at once:

```bash
#!/bin/bash
cd /home/daclab-ai/DEV/AWS-DevOps

# 1. Create IAM roles
./scripts/setup-partner-central-iam.sh

# 2. Create builder account profile
cat >> ~/.aws/config <<EOF

[profile partner-builder]
role_arn = arn:aws:iam::916873234430:role/OrganizationAccountAccessRole
source_profile = dfortini-local
region = us-east-2
output = json
EOF

# 3. Test builder account connection
echo "Testing builder account connection..."
aws sts get-caller-identity --profile partner-builder

# 4. Display role ARNs for Partner Central
echo ""
echo "=== Role ARNs for Partner Central ==="
aws iam get-role --role-name AWSPartnerCentralAccess --query 'Role.Arn' --output text
aws iam get-role --role-name AWSPartnerACEAccess --query 'Role.Arn' --output text
aws iam get-role --role-name AWSPartnerAllianceAccess --query 'Role.Arn' --output text

echo ""
echo "✓ Setup complete! Next steps:"
echo "1. Copy the role ARNs above"
echo "2. Go to https://partnercentral.aws.amazon.com/"
echo "3. Add roles in Settings > IAM Roles"
echo "4. Register builder account: 916873234430"
echo "5. Complete remaining tasks in Partner Central web interface"
```

## Troubleshooting

### "Access Denied" when running setup script

**Solution**: Ensure you're authenticated as `dfortini-local` in the master account:

```bash
aws sts get-caller-identity
# Should show Account: 313476888312
```

### "Role already exists" errors

**Solution**: This is fine. The script will update existing roles. To start fresh:

```bash
# Delete existing roles (careful!)
aws iam delete-role --role-name AWSPartnerCentralAccess
aws iam delete-role --role-name AWSPartnerACEAccess
aws iam delete-role --role-name AWSPartnerAllianceAccess

# Then re-run the setup script
./scripts/setup-partner-central-iam.sh
```

### Cannot access builder account

**Solution**: Verify the OrganizationAccountAccessRole exists:

```bash
aws iam get-role \
  --role-name OrganizationAccountAccessRole \
  --profile partner-builder
```

If it doesn't exist, create it:

```bash
# Switch to builder account (as root user or admin)
# Then create the role that allows management account access
```

### Partner Central can't verify my account

**Solution**:
1. Ensure IAM roles are in the **management account** (313476888312), not builder account
2. Verify the trust policy allows Partner Central account (905418367684)
3. Check that external ID is set to "PartnerCentral"

## Task Summary

| Priority | Task | Time | Automation |
|----------|------|------|------------|
| HIGH | Task 6: Create IAM Roles | <30min | ✓ Script available |
| HIGH | Task 3: Map Alliance Team | <30min | Manual (web UI) |
| HIGH | Task 4: Map ACE Users | <5min | Manual (web UI) |
| HIGH | Task 5: Assign User Role | <5min | Manual (web UI) |
| HIGH | Task 15: Assign Cloud Admin | <5min | Manual (web UI) |
| MEDIUM | Task 1: Schedule Migration | <4hrs | Manual (AWS processes) |
| MEDIUM | Task 14: Build Software Solution | >30min | Guided |
| MEDIUM | Task 8: Pay APN Fee | >30min | Manual (payment) |
| LOW | Task 2: Create PO Opportunity | >30min | Manual (web UI) |
| LOW | Task 7: AWS Marketplace Listing | 5min | Manual (web UI) |
| LOW | Task 17: Build Services Solution | <10min | Manual (web UI) |
| LOW | Task 9: Build Managed Services | <10min | Manual (web UI) |
| LOW | Task 10-13: Update Company Profile | <5min each | Manual (web UI) |
| LOW | Task 12: Invite Users | <5min | Manual (web UI) |
| LOW | Task 16: Learn Marketplace | <30min | Self-paced |

## Estimated Total Time

- **Automated setup**: 30 minutes
- **Web UI tasks**: 2-3 hours
- **Solution building**: 1-2 hours
- **Learning/review**: 1 hour

**Total**: Approximately 4-6 hours to complete all tasks.

## Next Steps

1. Run the IAM setup script: `./scripts/setup-partner-central-iam.sh`
2. Set up builder account profile
3. Go to Partner Central and complete web UI tasks
4. Build and submit your first solution
5. Create your first opportunity

## Resources

- [AWS Partner Central](https://partnercentral.aws.amazon.com/)
- [AWS Partner Network Overview](https://aws.amazon.com/partners/)
- [AWS Marketplace Seller Guide](https://docs.aws.amazon.com/marketplace/latest/userguide/)
- [APN Tier Comparison](https://aws.amazon.com/partners/programs/)
