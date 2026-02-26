#!/bin/bash
set -euo pipefail

# Create OrganizationAccountAccessRole in Builder Account
# This role allows the management account to access the builder account

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BUILDER_ACCOUNT_ID="916873234430"
MANAGEMENT_ACCOUNT_ID="313476888312"

echo -e "${YELLOW}Creating OrganizationAccountAccessRole in Builder Account${NC}"
echo "=========================================================================="
echo ""
echo "This script creates a role in the builder account that allows"
echo "the management account to access it for Partner Central setup."
echo ""

# Check if we're already in the builder account
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "unknown")

if [ "$CURRENT_ACCOUNT" = "$BUILDER_ACCOUNT_ID" ]; then
    echo -e "${GREEN}✓ Already authenticated in builder account${NC}"
else
    echo -e "${YELLOW}Current account: $CURRENT_ACCOUNT${NC}"
    echo ""
    echo "To create the role, you need to:"
    echo "1. Log into the builder account (916873234430) as root or admin"
    echo "2. Run this script again"
    echo ""
    echo "Alternatively, if you have root access, you can:"
    echo "  - Use the AWS Console to switch to the builder account"
    echo "  - Or configure AWS CLI with builder account credentials"
    echo ""

    # Provide CloudFormation template as alternative
    cat > /tmp/organization-access-role.yaml <<'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'OrganizationAccountAccessRole for cross-account access from management account'

Resources:
  OrganizationAccountAccessRole:
    Type: 'AWS::IAM::Role'
    Properties:
      RoleName: OrganizationAccountAccessRole
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::313476888312:root'
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/AdministratorAccess'
      Tags:
        - Key: ManagedBy
          Value: Organization
        - Key: Purpose
          Value: CrossAccountAccess

Outputs:
  RoleArn:
    Description: ARN of the OrganizationAccountAccessRole
    Value: !GetAtt OrganizationAccountAccessRole.Arn
EOF

    echo -e "${GREEN}CloudFormation template created: /tmp/organization-access-role.yaml${NC}"
    echo ""
    echo "You can deploy this in the builder account using:"
    echo "  1. Log into AWS Console for account 916873234430"
    echo "  2. Go to CloudFormation"
    echo "  3. Create Stack > Upload template"
    echo "  4. Upload /tmp/organization-access-role.yaml"
    echo "  5. Create stack"
    echo ""

    exit 1
fi

# If we're in the builder account, create the role
echo -e "${GREEN}Creating OrganizationAccountAccessRole...${NC}"

# Trust policy
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${MANAGEMENT_ACCOUNT_ID}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Check if role exists
if aws iam get-role --role-name OrganizationAccountAccessRole &>/dev/null; then
    echo -e "${YELLOW}Role already exists, updating trust policy${NC}"
    aws iam update-assume-role-policy \
        --role-name OrganizationAccountAccessRole \
        --policy-document file:///tmp/trust-policy.json
else
    # Create role
    aws iam create-role \
        --role-name OrganizationAccountAccessRole \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "Allows management account to access this builder account"

    # Attach AdministratorAccess policy
    aws iam attach-role-policy \
        --role-name OrganizationAccountAccessRole \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

    echo -e "${GREEN}✓ Role created successfully${NC}"
fi

# Display role ARN
ROLE_ARN=$(aws iam get-role --role-name OrganizationAccountAccessRole --query 'Role.Arn' --output text)
echo ""
echo -e "${GREEN}Role ARN: $ROLE_ARN${NC}"
echo ""
echo "You can now switch back to the management account and run:"
echo "  export AWS_PROFILE=partner-builder"
echo "  aws sts get-caller-identity"

rm -f /tmp/trust-policy.json
