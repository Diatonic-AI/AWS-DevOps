#!/bin/bash
set -euo pipefail

# Builder Account Connection Script
# This script helps you connect to your AWS builder account for Partner Central

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BUILDER_ACCOUNT_ID="916873234430"
BUILDER_ACCOUNT_NAME="Diatonic Dev"

echo -e "${BLUE}AWS Builder Account Connection Helper${NC}"
echo "========================================"
echo ""

# Check current identity
echo -e "${YELLOW}Current AWS Identity:${NC}"
aws sts get-caller-identity

echo ""
echo -e "${YELLOW}Builder Account Details:${NC}"
echo "Account ID: $BUILDER_ACCOUNT_ID"
echo "Account Name: $BUILDER_ACCOUNT_NAME"
echo ""

# Function to add profile to AWS config
add_builder_profile() {
    local config_file="$HOME/.aws/config"
    local profile_name="partner-builder"

    # Check if profile already exists
    if grep -q "\[profile $profile_name\]" "$config_file" 2>/dev/null; then
        echo -e "${YELLOW}Profile '$profile_name' already exists in $config_file${NC}"
        echo "Skipping profile creation."
        return 0
    fi

    echo -e "${GREEN}Adding '$profile_name' profile to AWS config...${NC}"

    cat >> "$config_file" <<EOF

[profile $profile_name]
role_arn = arn:aws:iam::${BUILDER_ACCOUNT_ID}:role/OrganizationAccountAccessRole
source_profile = dfortini-local
region = us-east-2
output = json
EOF

    echo -e "${GREEN}✓ Profile added successfully${NC}"
}

# Function to test builder account access
test_builder_access() {
    local profile_name="partner-builder"

    echo ""
    echo -e "${YELLOW}Testing builder account access...${NC}"

    if aws sts get-caller-identity --profile "$profile_name" &>/dev/null; then
        echo -e "${GREEN}✓ Successfully connected to builder account!${NC}"
        echo ""
        echo "Builder account identity:"
        aws sts get-caller-identity --profile "$profile_name"

        echo ""
        echo -e "${GREEN}To use this account, run:${NC}"
        echo "  export AWS_PROFILE=$profile_name"
        echo ""
        echo "Or use the profile in commands:"
        echo "  aws <command> --profile $profile_name"

        return 0
    else
        echo -e "${YELLOW}⚠ Could not access builder account${NC}"
        echo ""
        echo "This might mean:"
        echo "1. The OrganizationAccountAccessRole doesn't exist in the builder account"
        echo "2. Your dfortini-local user doesn't have permission to assume the role"
        echo "3. The role trust policy needs to be updated"
        echo ""
        echo "To fix this, you may need to:"
        echo "1. Log into the builder account as root or admin"
        echo "2. Create the OrganizationAccountAccessRole"
        echo "3. Add a trust policy allowing account 313476888312 to assume it"

        return 1
    fi
}

# Function to create assume-role script
create_assume_role_script() {
    local script_path="/home/daclab-ai/DEV/AWS-DevOps/scripts/assume-builder-role.sh"

    echo ""
    echo -e "${GREEN}Creating assume-role helper script...${NC}"

    cat > "$script_path" <<'EOF'
#!/bin/bash
# Quick script to get temporary credentials for builder account

ROLE_ARN="arn:aws:iam::916873234430:role/OrganizationAccountAccessRole"
SESSION_NAME="partner-builder-$(date +%s)"

echo "Assuming role: $ROLE_ARN"
echo "Session name: $SESSION_NAME"
echo ""

# Get credentials
CREDS=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "$SESSION_NAME" \
  --duration-seconds 3600 \
  --output json)

# Extract credentials
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

echo "✓ Credentials exported to environment variables"
echo "Valid for: 1 hour"
echo ""
echo "Test with:"
echo "  aws sts get-caller-identity"
echo ""
echo "To revert to your original credentials, run:"
echo "  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN"
EOF

    chmod +x "$script_path"
    echo -e "${GREEN}✓ Created: $script_path${NC}"
}

# Function to display builder account resources
show_builder_resources() {
    local profile_name="partner-builder"

    echo ""
    echo -e "${YELLOW}Builder Account Resources:${NC}"
    echo "========================================"

    echo ""
    echo "EC2 Instances:"
    aws ec2 describe-instances \
      --profile "$profile_name" \
      --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]' \
      --output table 2>/dev/null || echo "  No instances found or no access"

    echo ""
    echo "ECR Repositories:"
    aws ecr describe-repositories \
      --profile "$profile_name" \
      --query 'repositories[*].[repositoryName,repositoryUri]' \
      --output table 2>/dev/null || echo "  No repositories found or no access"

    echo ""
    echo "Lambda Functions:"
    aws lambda list-functions \
      --profile "$profile_name" \
      --query 'Functions[*].[FunctionName,Runtime,LastModified]' \
      --output table 2>/dev/null || echo "  No functions found or no access"

    echo ""
    echo "S3 Buckets:"
    aws s3 ls --profile "$profile_name" 2>/dev/null || echo "  No buckets found or no access"
}

# Main execution
echo -e "${BLUE}Step 1: Add Builder Profile to AWS Config${NC}"
add_builder_profile

echo ""
echo -e "${BLUE}Step 2: Test Builder Account Access${NC}"
if test_builder_access; then
    echo ""
    echo -e "${BLUE}Step 3: Create Additional Helper Scripts${NC}"
    create_assume_role_script

    echo ""
    echo -e "${BLUE}Step 4: Show Builder Account Resources${NC}"
    show_builder_resources

    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}Builder Account Connection Complete!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "Next steps for Partner Central:"
    echo "1. Go to https://partnercentral.aws.amazon.com/"
    echo "2. Navigate to Settings > AWS Accounts"
    echo "3. Click 'Add Account'"
    echo "4. Enter Account ID: $BUILDER_ACCOUNT_ID"
    echo "5. Enter Account Alias: diatonic-dev-builder"
    echo "6. Select Account Type: Builder Account"
    echo "7. Click 'Verify Account'"
    echo ""
else
    echo ""
    echo -e "${YELLOW}Builder account access could not be verified.${NC}"
    echo "Please check the troubleshooting steps above."
    echo ""
    echo "You can still manually assume the role using:"
    echo "  aws sts assume-role --role-arn arn:aws:iam::$BUILDER_ACCOUNT_ID:role/OrganizationAccountAccessRole --role-session-name partner-builder"
fi
