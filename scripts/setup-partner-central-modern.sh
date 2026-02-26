#!/bin/bash
set -euo pipefail

# AWS Partner Central IAM Setup - Modern Approach (Console Migration)
# Based on AWS official documentation for Partner Central in AWS Console
# https://docs.aws.amazon.com/partner-central/latest/getting-started/

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}"
cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   AWS Partner Central - Modern IAM Setup                    ║
║   For Partner Central in AWS Console Migration              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Phase 0: Account Decision
echo -e "${YELLOW}Phase 0: Account Strategy Decision${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "AWS Recommendation: Use a DEDICATED account for Partner Central"
echo "  ❌ NOT your organization management account"
echo "  ❌ NOT your production/dev/sandbox account"
echo "  ❌ NOT a Marketplace buyer account"
echo "  ✅ A dedicated member account in your organization"
echo ""
echo "Current account:"
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
CURRENT_ARN=$(aws sts get-caller-identity --query 'Arn' --output text)
echo "  Account ID: $CURRENT_ACCOUNT"
echo "  Identity: $CURRENT_ARN"
echo ""

# Check if this is the org management account
ORG_MASTER=$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text 2>/dev/null || echo "N/A")
if [ "$CURRENT_ACCOUNT" = "$ORG_MASTER" ]; then
    echo -e "${RED}⚠️  WARNING: You are in the organization MANAGEMENT account${NC}"
    echo "   AWS recommends using a dedicated MEMBER account instead."
    echo ""
    read -p "Do you want to continue anyway? (yes/NO) " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Exiting. Please switch to a dedicated member account."
        exit 1
    fi
else
    echo -e "${GREEN}✓ You are in a member account (good practice)${NC}"
fi

echo ""
read -p "Use this account ($CURRENT_ACCOUNT) as your Partner Central linked account? (yes/NO) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Exiting. Please authenticate to your chosen Partner Central account."
    exit 0
fi

# Phase 3: Create roles with correct naming and trust policies
echo ""
echo -e "${BLUE}Phase 3: Creating Partner Central IAM Roles${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "AWS Requirements:"
echo "  1. Role names MUST start with 'PartnerCentralRoleFor'"
echo "  2. Trust policy MUST trust 'partnercentral-account-management.amazonaws.com'"
echo "  3. Attach appropriate AWS-managed policies"
echo ""

# Trust policy for all Partner Central roles
TRUST_POLICY=$(cat <<'EOF'
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
EOF
)

# Function to create Partner Central role
create_pc_role() {
    local role_name=$1
    local description=$2
    shift 2
    local policies=("$@")

    echo ""
    echo -e "${YELLOW}Creating role: $role_name${NC}"

    # Check if role exists
    if aws iam get-role --role-name "$role_name" &>/dev/null; then
        echo -e "${YELLOW}  Role exists, updating trust policy${NC}"
        echo "$TRUST_POLICY" | aws iam update-assume-role-policy \
            --role-name "$role_name" \
            --policy-document file:///dev/stdin
    else
        # Create role
        echo "$TRUST_POLICY" | aws iam create-role \
            --role-name "$role_name" \
            --assume-role-policy-document file:///dev/stdin \
            --description "$description" \
            --tags Key=ManagedBy,Value=PartnerCentral Key=Purpose,Value=PartnerCentralMigration
        echo -e "${GREEN}  ✓ Created role${NC}"
    fi

    # Attach policies
    for policy_arn in "${policies[@]}"; do
        policy_name=$(basename "$policy_arn")
        if aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Attached: $policy_name${NC}"
        else
            echo -e "${YELLOW}  Already attached: $policy_name${NC}"
        fi
    done

    # Get role ARN
    local role_arn=$(aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text)
    echo -e "${GREEN}  ARN: $role_arn${NC}"
}

# Phase 4: Create roles for each persona
echo ""
echo -e "${BLUE}Phase 4: Creating Persona-Based Roles${NC}"
echo "═══════════════════════════════════════════════════════════"

# Role 1: Alliance Lead (Full Partner Central + Marketplace)
create_pc_role \
    "PartnerCentralRoleForAllianceLead" \
    "Full Partner Central access including Marketplace management" \
    "arn:aws:iam::aws:policy/AWSPartnerCentralFullAccess" \
    "arn:aws:iam::aws:policy/AWSMarketplaceSellerFullAccess"

# Role 2: ACE Manager (Opportunity Management)
create_pc_role \
    "PartnerCentralRoleForACEManager" \
    "Partner Central opportunity management for AWS Customer Engagement" \
    "arn:aws:iam::aws:policy/AWSPartnerCentralOpportunityManagement" \
    "arn:aws:iam::aws:policy/aws-marketplace-management:AWSMarketplaceAmiIngestion"

# Role 3: Marketing User (Marketing Management)
create_pc_role \
    "PartnerCentralRoleForMarketing" \
    "Partner Central marketing campaign and asset management" \
    "arn:aws:iam::aws:policy/AWSPartnerCentralMarketingManagement"

# Role 4: Channel Manager (Channel Management)
create_pc_role \
    "PartnerCentralRoleForChannelManager" \
    "Partner Central channel partner and handshake management" \
    "arn:aws:iam::aws:policy/AWSPartnerCentralChannelManagement"

# Role 5: Channel Approver (Channel Handshake Approvals Only)
create_pc_role \
    "PartnerCentralRoleForChannelApprover" \
    "Partner Central channel handshake approval authority only" \
    "arn:aws:iam::aws:policy/AWSPartnerCentralChannelHandshakeApprovalManagement"

# Role 6: Technical Staff (Marketplace Product Management)
create_pc_role \
    "PartnerCentralRoleForTechnical" \
    "Marketplace product and solution management for technical staff" \
    "arn:aws:iam::aws:policy/AWSMarketplaceSellerProductsFullAccess"

# Role 7: Read-Only User (for auditors, observers)
create_pc_role \
    "PartnerCentralRoleForReadOnly" \
    "Read-only access to Partner Central for reporting and auditing" \
    "arn:aws:iam::aws:policy/ReadOnlyAccess"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}✓ Partner Central IAM Roles Created Successfully${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Display all roles
echo "Created Roles (ready for user mapping in Partner Central):"
echo "────────────────────────────────────────────────────────────"
aws iam list-roles --query "Roles[?starts_with(RoleName,'PartnerCentralRoleFor')].[RoleName,Arn]" --output table

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "────────────────────────────────────────────────────────────"
echo "1. Go to AWS Partner Central Console Migration wizard"
echo "2. Download current Partner Central users (migration widget)"
echo "3. Map each user to appropriate IAM role:"
echo ""
echo "   User Type                  → Recommended Role"
echo "   ─────────────────────────────────────────────────────────"
echo "   Alliance Lead/Cloud Admin  → PartnerCentralRoleForAllianceLead"
echo "   ACE/Opportunity Manager    → PartnerCentralRoleForACEManager"
echo "   Marketing Team             → PartnerCentralRoleForMarketing"
echo "   Channel Partners           → PartnerCentralRoleForChannelManager"
echo "   Channel Approvers          → PartnerCentralRoleForChannelApprover"
echo "   Technical/Solution Staff   → PartnerCentralRoleForTechnical"
echo "   Auditors/Read-Only         → PartnerCentralRoleForReadOnly"
echo ""
echo "4. Schedule migration (2-6 hours, non-business hours recommended)"
echo "5. Users will be blocked during migration - plan accordingly"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  Prerequisites: https://docs.aws.amazon.com/partner-central/latest/getting-started/linking-prerequisites.html"
echo "  Account Linking: https://docs.aws.amazon.com/partner-central/latest/getting-started/account-linking.html"
echo "  Migration Guide: https://docs.aws.amazon.com/partner-central/latest/getting-started/migrating-to-partner-central.html"
echo ""
