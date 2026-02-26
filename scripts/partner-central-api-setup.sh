#!/bin/bash
set -euo pipefail

# AWS Partner Central Programmatic Configuration
# This script uses AWS CLI and APIs to configure Partner Central

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}"
cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   AWS Partner Central - Programmatic Configuration          ║
║   Using AWS CLI and APIs                                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Configuration
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
REGION="${AWS_REGION:-us-east-2}"

echo -e "${YELLOW}Current Configuration:${NC}"
echo "  Account ID: $ACCOUNT_ID"
echo "  Region: $REGION"
echo ""

# Function to verify IAM roles
verify_iam_roles() {
    echo -e "${BLUE}Step 1: Verifying IAM Roles${NC}"
    echo "══════════════════════════════════════════════════════════"

    local roles=(
        "AWSPartnerCentralAccess"
        "AWSPartnerACEAccess"
        "AWSPartnerAllianceAccess"
    )

    for role in "${roles[@]}"; do
        if aws iam get-role --role-name "$role" &>/dev/null; then
            echo -e "${GREEN}✓ $role exists${NC}"

            # Get role details
            local role_arn=$(aws iam get-role --role-name "$role" --query 'Role.Arn' --output text)
            echo "  ARN: $role_arn"

            # List attached policies
            local policies=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyName' --output text)
            echo "  Policies: $policies"
        else
            echo -e "${RED}✗ $role NOT FOUND${NC}"
        fi
        echo ""
    done
}

# Function to check organization setup
check_organization() {
    echo -e "${BLUE}Step 2: Verifying AWS Organization${NC}"
    echo "══════════════════════════════════════════════════════════"

    if aws organizations describe-organization &>/dev/null; then
        local org_id=$(aws organizations describe-organization --query 'Organization.Id' --output text)
        local master_id=$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text)

        echo -e "${GREEN}✓ Organization configured${NC}"
        echo "  Organization ID: $org_id"
        echo "  Management Account: $master_id"
        echo ""

        # List accounts
        echo "Organization Accounts:"
        aws organizations list-accounts --query 'Accounts[].[Id,Name,Status]' --output table
    else
        echo -e "${YELLOW}⚠ Not in an organization or no permissions${NC}"
    fi
    echo ""
}

# Function to export Partner Central configuration
export_configuration() {
    echo -e "${BLUE}Step 3: Exporting Partner Central Configuration${NC}"
    echo "══════════════════════════════════════════════════════════"

    local config_file="/tmp/partner-central-config.json"

    cat > "$config_file" <<EOF
{
  "account_id": "$ACCOUNT_ID",
  "region": "$REGION",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "iam_roles": {
    "partner_central_access": "arn:aws:iam::$ACCOUNT_ID:role/AWSPartnerCentralAccess",
    "ace_access": "arn:aws:iam::$ACCOUNT_ID:role/AWSPartnerACEAccess",
    "alliance_access": "arn:aws:iam::$ACCOUNT_ID:role/AWSPartnerAllianceAccess"
  },
  "organization": {
    "id": "$(aws organizations describe-organization --query 'Organization.Id' --output text 2>/dev/null || echo 'N/A')",
    "management_account": "$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text 2>/dev/null || echo 'N/A')"
  },
  "builder_accounts": [
    {
      "account_id": "916873234430",
      "name": "Diatonic Dev",
      "purpose": "Solution development and testing"
    }
  ]
}
EOF

    echo -e "${GREEN}✓ Configuration exported to: $config_file${NC}"
    cat "$config_file" | jq '.'
    echo ""
}

# Function to create CloudFormation stack for Partner Central
create_cloudformation_stack() {
    echo -e "${BLUE}Step 4: Creating CloudFormation Stack (Optional)${NC}"
    echo "══════════════════════════════════════════════════════════"

    local stack_name="partner-central-infrastructure"
    local template_file="/tmp/partner-central-stack.yaml"

    cat > "$template_file" <<'YAML'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS Partner Central Infrastructure'

Parameters:
  PartnerCentralAccountId:
    Type: String
    Default: '905418367684'
    Description: AWS Partner Central service account ID

Resources:
  PartnerCentralAccessRole:
    Type: 'AWS::IAM::Role'
    Properties:
      RoleName: AWSPartnerCentralAccess
      AssumeRolePolicyDocument:
        Version: '2012-10-09'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${PartnerCentralAccountId}:root'
            Action: 'sts:AssumeRole'
            Condition:
              StringEquals:
                'sts:ExternalId': 'PartnerCentral'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/ReadOnlyAccess'
        - 'arn:aws:iam::aws:policy/AWSMarketplaceSellerFullAccess'
      Tags:
        - Key: Purpose
          Value: PartnerCentral
        - Key: ManagedBy
          Value: CloudFormation

  PartnerCentralACERole:
    Type: 'AWS::IAM::Role'
    Properties:
      RoleName: AWSPartnerACEAccess
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${PartnerCentralAccountId}:root'
            Action: 'sts:AssumeRole'
            Condition:
              StringEquals:
                'sts:ExternalId': 'PartnerCentral'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/ReadOnlyAccess'
      Tags:
        - Key: Purpose
          Value: PartnerCentralACE

  PartnerCentralAllianceRole:
    Type: 'AWS::IAM::Role'
    Properties:
      RoleName: AWSPartnerAllianceAccess
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${PartnerCentralAccountId}:root'
            Action: 'sts:AssumeRole'
            Condition:
              StringEquals:
                'sts:ExternalId': 'PartnerCentral'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/ReadOnlyAccess'
        - 'arn:aws:iam::aws:policy/AWSMarketplaceSellerFullAccess'
      Tags:
        - Key: Purpose
          Value: PartnerCentralAlliance

Outputs:
  PartnerCentralAccessRoleArn:
    Description: ARN of Partner Central Access Role
    Value: !GetAtt PartnerCentralAccessRole.Arn
    Export:
      Name: PartnerCentralAccessRoleArn

  ACEAccessRoleArn:
    Description: ARN of ACE Access Role
    Value: !GetAtt PartnerCentralACERole.Arn
    Export:
      Name: PartnerCentralACEAccessRoleArn

  AllianceAccessRoleArn:
    Description: ARN of Alliance Access Role
    Value: !GetAtt PartnerCentralAllianceRole.Arn
    Export:
      Name: PartnerCentralAllianceAccessRoleArn
YAML

    echo "CloudFormation template created: $template_file"
    echo ""
    echo "To deploy this stack, run:"
    echo "  aws cloudformation create-stack \\"
    echo "    --stack-name $stack_name \\"
    echo "    --template-body file://$template_file \\"
    echo "    --capabilities CAPABILITY_NAMED_IAM"
    echo ""
}

# Function to test role assumptions
test_role_assumptions() {
    echo -e "${BLUE}Step 5: Testing Role Assumptions${NC}"
    echo "══════════════════════════════════════════════════════════"

    local roles=(
        "AWSPartnerCentralAccess"
        "AWSPartnerACEAccess"
        "AWSPartnerAllianceAccess"
    )

    for role in "${roles[@]}"; do
        local role_arn="arn:aws:iam::$ACCOUNT_ID:role/$role"
        echo "Testing: $role"

        # Get role trust policy
        local trust_policy=$(aws iam get-role --role-name "$role" --query 'Role.AssumeRolePolicyDocument' 2>/dev/null)

        if [ $? -eq 0 ]; then
            echo "  Trust Policy:"
            echo "$trust_policy" | jq '.Statement[0].Principal'
            echo ""
        else
            echo -e "${RED}  ✗ Could not retrieve trust policy${NC}"
        fi
    done
}

# Function to create AWS Marketplace integration script
create_marketplace_integration() {
    echo -e "${BLUE}Step 6: AWS Marketplace Integration${NC}"
    echo "══════════════════════════════════════════════════════════"

    local marketplace_script="/tmp/marketplace-integration.sh"

    cat > "$marketplace_script" <<'SCRIPT'
#!/bin/bash
# AWS Marketplace Integration for Partner Central

# Check Marketplace seller status
check_seller_status() {
    echo "Checking AWS Marketplace seller status..."

    # Note: Marketplace Catalog API requires seller enrollment
    # This is a placeholder for actual marketplace operations
    echo "Use AWS Marketplace Management Portal for:"
    echo "  - Product listings"
    echo "  - Pricing configuration"
    echo "  - Private offers"
    echo ""
    echo "Portal: https://aws.amazon.com/marketplace/management/"
}

# List marketplace products (if enrolled)
list_products() {
    echo "Marketplace products would be listed here"
    echo "(Requires Marketplace Catalog API access)"
}

check_seller_status
SCRIPT

    chmod +x "$marketplace_script"
    echo -e "${GREEN}✓ Marketplace integration script created: $marketplace_script${NC}"
    echo ""
}

# Main execution
main() {
    verify_iam_roles
    check_organization
    export_configuration
    create_cloudformation_stack
    test_role_assumptions
    create_marketplace_integration

    echo -e "${GREEN}${BOLD}"
    echo "══════════════════════════════════════════════════════════"
    echo "✓ Partner Central Programmatic Setup Complete"
    echo "══════════════════════════════════════════════════════════"
    echo -e "${NC}"

    echo ""
    echo -e "${YELLOW}Next Steps for Programmatic Management:${NC}"
    echo ""
    echo "1. AWS SDK Integration:"
    echo "   - Python: boto3 for Partner Central APIs"
    echo "   - Node.js: AWS SDK for JavaScript"
    echo "   - Java: AWS SDK for Java"
    echo ""
    echo "2. Infrastructure as Code:"
    echo "   - CloudFormation stack template created"
    echo "   - Terraform modules available"
    echo ""
    echo "3. API Operations:"
    echo "   - Partner Central REST APIs (via AWS SDK)"
    echo "   - Marketplace Catalog API"
    echo "   - Organizations API (for account management)"
    echo ""
    echo "4. Automation:"
    echo "   - CI/CD pipelines for solution deployment"
    echo "   - Automated opportunity creation"
    echo "   - Programmatic user management"
    echo ""
}

main
