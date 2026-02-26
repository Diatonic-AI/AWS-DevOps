#!/bin/bash
set -euo pipefail

# AWS Partner Central IAM Setup Script
# This script creates the necessary IAM roles for AWS Partner Central integration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MASTER_ACCOUNT_ID="313476888312"
BUILDER_ACCOUNT_ID="${BUILDER_ACCOUNT_ID:-916873234430}"  # Diatonic Dev by default
PARTNER_CENTRAL_ACCOUNT_ID="905418367684"  # AWS Partner Central account ID

echo -e "${GREEN}AWS Partner Central IAM Role Setup${NC}"
echo "================================================"
echo "Master Account: $MASTER_ACCOUNT_ID (DiatonicAI)"
echo "Builder Account: $BUILDER_ACCOUNT_ID (Diatonic Dev)"
echo ""

# Function to create Partner Central access role
create_partner_central_role() {
    local role_name=$1
    local description=$2
    local account_id=$3

    echo -e "${YELLOW}Creating IAM role: $role_name${NC}"

    # Create trust policy for Partner Central
    cat > /tmp/partner-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${PARTNER_CENTRAL_ACCOUNT_ID}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "PartnerCentral"
        }
      }
    }
  ]
}
EOF

    # Create the role
    if aws iam get-role --role-name "$role_name" &>/dev/null; then
        echo -e "${YELLOW}Role $role_name already exists, updating trust policy${NC}"
        aws iam update-assume-role-policy \
            --role-name "$role_name" \
            --policy-document file:///tmp/partner-trust-policy.json
    else
        aws iam create-role \
            --role-name "$role_name" \
            --assume-role-policy-document file:///tmp/partner-trust-policy.json \
            --description "$description" \
            --tags Key=ManagedBy,Value=PartnerCentral Key=Purpose,Value=AWSPartnerIntegration

        echo -e "${GREEN}✓ Created role: $role_name${NC}"
    fi

    # Clean up temp file
    rm -f /tmp/partner-trust-policy.json
}

# Function to attach managed policies
attach_partner_policies() {
    local role_name=$1

    echo -e "${YELLOW}Attaching managed policies to $role_name${NC}"

    # Partner Central typically needs these policies:
    local policies=(
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
        "arn:aws:iam::aws:policy/AWSMarketplaceSellerFullAccess"
    )

    for policy in "${policies[@]}"; do
        if aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy" 2>/dev/null; then
            echo -e "${GREEN}✓ Attached: $(basename $policy)${NC}"
        else
            echo -e "${YELLOW}  Policy already attached or not available: $(basename $policy)${NC}"
        fi
    done
}

# Function to create custom Partner Central policy
create_custom_partner_policy() {
    local role_name=$1

    echo -e "${YELLOW}Creating custom Partner Central policy${NC}"

    cat > /tmp/partner-custom-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PartnerCentralAccess",
      "Effect": "Allow",
      "Action": [
        "cloudformation:DescribeStacks",
        "cloudformation:ListStacks",
        "cloudformation:GetTemplate",
        "ec2:Describe*",
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation",
        "lambda:List*",
        "lambda:Get*",
        "apigateway:GET",
        "dynamodb:List*",
        "dynamodb:DescribeTable",
        "rds:Describe*",
        "ecs:Describe*",
        "ecs:List*",
        "eks:Describe*",
        "eks:List*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

    local policy_name="${role_name}Policy"

    # Check if policy exists
    local policy_arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$policy_name'].Arn" --output text)

    if [ -z "$policy_arn" ]; then
        policy_arn=$(aws iam create-policy \
            --policy-name "$policy_name" \
            --policy-document file:///tmp/partner-custom-policy.json \
            --description "Custom policy for AWS Partner Central access" \
            --query 'Policy.Arn' \
            --output text)
        echo -e "${GREEN}✓ Created custom policy: $policy_name${NC}"
    else
        echo -e "${YELLOW}Custom policy already exists: $policy_name${NC}"
    fi

    # Attach custom policy to role
    aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn"
    echo -e "${GREEN}✓ Attached custom policy to role${NC}"

    rm -f /tmp/partner-custom-policy.json
}

# Main execution
echo ""
echo "Step 1: Creating Partner Central Access Role"
echo "=============================================="
create_partner_central_role "AWSPartnerCentralAccess" "Role for AWS Partner Central integration" "$MASTER_ACCOUNT_ID"
attach_partner_policies "AWSPartnerCentralAccess"
create_custom_partner_policy "AWSPartnerCentralAccess"

echo ""
echo "Step 2: Creating ACE User Access Role"
echo "======================================="
create_partner_central_role "AWSPartnerACEAccess" "Role for AWS Partner ACE users" "$MASTER_ACCOUNT_ID"

# ACE users typically need more restricted access
cat > /tmp/ace-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ACEUserAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "s3:ListBucket",
        "s3:GetObject",
        "cloudformation:DescribeStacks",
        "cloudformation:ListStacks"
      ],
      "Resource": "*"
    }
  ]
}
EOF

policy_arn=$(aws iam create-policy \
    --policy-name "AWSPartnerACEAccessPolicy" \
    --policy-document file:///tmp/ace-policy.json \
    --description "Policy for AWS Partner ACE users" \
    --query 'Policy.Arn' \
    --output text 2>/dev/null || aws iam list-policies --scope Local --query "Policies[?PolicyName=='AWSPartnerACEAccessPolicy'].Arn" --output text)

aws iam attach-role-policy --role-name "AWSPartnerACEAccess" --policy-arn "$policy_arn"
echo -e "${GREEN}✓ Created and attached ACE access policy${NC}"
rm -f /tmp/ace-policy.json

echo ""
echo "Step 3: Creating Alliance Team Access Role"
echo "==========================================="
create_partner_central_role "AWSPartnerAllianceAccess" "Role for AWS Alliance team access" "$MASTER_ACCOUNT_ID"
attach_partner_policies "AWSPartnerAllianceAccess"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}IAM Roles Created Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Role ARNs to use in Partner Central:"
echo "-------------------------------------"
aws iam get-role --role-name AWSPartnerCentralAccess --query 'Role.Arn' --output text
aws iam get-role --role-name AWSPartnerACEAccess --query 'Role.Arn' --output text
aws iam get-role --role-name AWSPartnerAllianceAccess --query 'Role.Arn' --output text

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Copy the role ARNs above"
echo "2. Go to AWS Partner Central (https://partnercentral.aws.amazon.com/)"
echo "3. Navigate to Settings > IAM Roles"
echo "4. Add these role ARNs to your Partner Central configuration"
echo "5. Complete the remaining tasks in Partner Central"
echo ""
echo -e "${GREEN}Builder Account Setup:${NC}"
echo "Your builder account is: $BUILDER_ACCOUNT_ID (Diatonic Dev)"
echo "To switch to builder account:"
echo "  aws sts assume-role --role-arn arn:aws:iam::$BUILDER_ACCOUNT_ID:role/OrganizationAccountAccessRole --role-session-name partner-central-setup"
