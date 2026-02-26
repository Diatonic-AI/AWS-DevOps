#!/bin/bash
set -euo pipefail

# AWS Partner Central Quick Start
# This script automates the setup of IAM roles and builder account connection

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BOLD}${BLUE}"
cat <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║      AWS Partner Central Quick Start                     ║
║      Complete Setup in Minutes                           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verify we're in the right account
echo -e "${YELLOW}Verifying AWS credentials...${NC}"
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
CURRENT_USER=$(aws sts get-caller-identity --query 'Arn' --output text)

if [ "$CURRENT_ACCOUNT" != "313476888312" ]; then
    echo -e "${RED}ERROR: You must be authenticated in the management account (313476888312)${NC}"
    echo "Current account: $CURRENT_ACCOUNT"
    echo ""
    echo "Please run:"
    echo "  export AWS_PROFILE=dfortini-local"
    echo "  # or authenticate as dfortini-local user"
    exit 1
fi

echo -e "${GREEN}✓ Authenticated as: $CURRENT_USER${NC}"
echo -e "${GREEN}✓ Account: $CURRENT_ACCOUNT (DiatonicAI - Management Account)${NC}"
echo ""

# Confirm before proceeding
echo -e "${YELLOW}This script will:${NC}"
echo "  1. Create IAM roles for Partner Central integration"
echo "  2. Set up builder account connection profile"
echo "  3. Verify builder account access"
echo "  4. Display role ARNs for Partner Central configuration"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Step 1: Creating Partner Central IAM Roles${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ -f "$SCRIPTS_DIR/setup-partner-central-iam.sh" ]; then
    bash "$SCRIPTS_DIR/setup-partner-central-iam.sh"
else
    echo -e "${RED}ERROR: setup-partner-central-iam.sh not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Step 2: Connecting to Builder Account${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ -f "$SCRIPTS_DIR/connect-builder-account.sh" ]; then
    bash "$SCRIPTS_DIR/connect-builder-account.sh"
else
    echo -e "${RED}ERROR: connect-builder-account.sh not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Step 3: Generating Partner Central Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Create configuration file
CONFIG_FILE="/home/daclab-ai/DEV/AWS-DevOps/partner-central-config.txt"

cat > "$CONFIG_FILE" <<EOF
AWS Partner Central Configuration
Generated: $(date)
==================================================

MANAGEMENT ACCOUNT
--------------------------------------------------
Account ID: 313476888312
Account Name: DiatonicAI
Organization ID: o-eyf5fcwrr3
Current User: dfortini-local

BUILDER ACCOUNT
--------------------------------------------------
Account ID: 916873234430
Account Name: Diatonic Dev
Account Alias: diatonic-dev-builder

IAM ROLE ARNs (Copy these to Partner Central)
--------------------------------------------------
Partner Central Access Role:
$(aws iam get-role --role-name AWSPartnerCentralAccess --query 'Role.Arn' --output text 2>/dev/null || echo "Not created")

ACE User Access Role:
$(aws iam get-role --role-name AWSPartnerACEAccess --query 'Role.Arn' --output text 2>/dev/null || echo "Not created")

Alliance Team Access Role:
$(aws iam get-role --role-name AWSPartnerAllianceAccess --query 'Role.Arn' --output text 2>/dev/null || echo "Not created")

PARTNER CENTRAL TASKS QUICK REFERENCE
==================================================

COMPLETED AUTOMATICALLY:
✓ Task 6: Create IAM Roles

TO COMPLETE IN PARTNER CENTRAL WEB UI:
□ Task 1: Schedule Migration (https://partnercentral.aws.amazon.com/)
□ Task 2: Create Partner Originated Opportunity
□ Task 3: Map Alliance Team to IAM Roles (use Alliance Team ARN above)
□ Task 4: Map ACE Users to IAM Roles (use ACE User ARN above)
□ Task 5: Assign User Role (assign Drew Fortini as Account Administrator)
□ Task 7: Create AWS Marketplace Listing
□ Task 8: Pay APN Fee (Select tier: \$2,500/year recommended)
□ Task 9: Build Managed Services Solution
□ Task 10: Update Company Profile - Technology Team Size
□ Task 11: Update Company Profile - Marketing Team Size
□ Task 12: Invite Users to Join Partner Central
□ Task 13: Update Company Profile - Sales Team Size
□ Task 14: Build First Software Solution (use builder account: 916873234430)
□ Task 15: Assign Cloud Admin
□ Task 16: Learn AWS Marketplace Benefits
□ Task 17: Build Services Solution

NEXT STEPS
==================================================

1. Go to AWS Partner Central:
   https://partnercentral.aws.amazon.com/

2. Add IAM Roles (Settings > IAM Roles):
   - Add the three role ARNs listed above

3. Register Builder Account (Settings > AWS Accounts):
   - Account ID: 916873234430
   - Account Alias: diatonic-dev-builder
   - Account Type: Builder Account

4. Complete remaining tasks in Partner Central web interface

5. To use builder account with AWS CLI:
   export AWS_PROFILE=partner-builder

DOCUMENTATION
==================================================

Full setup guide:
/home/daclab-ai/DEV/AWS-DevOps/docs/PARTNER-CENTRAL-SETUP.md

IAM setup script:
/home/daclab-ai/DEV/AWS-DevOps/scripts/setup-partner-central-iam.sh

Builder account connection:
/home/daclab-ai/DEV/AWS-DevOps/scripts/connect-builder-account.sh

Assume builder role manually:
/home/daclab-ai/DEV/AWS-DevOps/scripts/assume-builder-role.sh

SUPPORT
==================================================

AWS Partner Central Support:
https://support.console.aws.amazon.com/support/home

APN Customer Engagement (ACE):
Contact through Partner Central

AWS Marketplace Seller Support:
https://aws.amazon.com/marketplace/management/contact-us
EOF

echo -e "${GREEN}✓ Configuration saved to: $CONFIG_FILE${NC}"
echo ""

# Display summary
cat "$CONFIG_FILE"

echo ""
echo -e "${GREEN}${BOLD}"
cat <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║      ✓ Setup Complete!                                   ║
║                                                           ║
║      Next: Complete web UI tasks in Partner Central      ║
║      https://partnercentral.aws.amazon.com/               ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Open configuration file
echo -e "${YELLOW}Configuration details saved to:${NC}"
echo "  $CONFIG_FILE"
echo ""
echo -e "${YELLOW}View full documentation:${NC}"
echo "  /home/daclab-ai/DEV/AWS-DevOps/docs/PARTNER-CENTRAL-SETUP.md"
echo ""
