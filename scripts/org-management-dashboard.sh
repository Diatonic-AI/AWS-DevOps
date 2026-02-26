#!/bin/bash

# Organization Management Dashboard for DiatonicAI Management Account
# Account: 313476888312 | User: dfortini-local | Organization: o-eyf5fcwrr3

PROFILE="dfortini-local"
ORG_ID="o-eyf5fcwrr3"
MGMT_ACCOUNT="313476888312"

echo "🏢 DIATONIC ORGANIZATION MANAGEMENT DASHBOARD"
echo "=============================================="
echo "Management Account: $MGMT_ACCOUNT (DiatonicAI)"
echo "Organization ID: $ORG_ID"
echo "Administrator: dfortini-local"
echo "Timestamp: $(date)"
echo ""

# 1. ORGANIZATION HEALTH CHECK
echo "📊 1. ORGANIZATION HEALTH CHECK"
echo "==============================="
echo ""
echo "Organization Details:"
aws organizations describe-organization --profile $PROFILE --query 'Organization.{Id:Id,MasterAccountId:MasterAccountId,FeatureSet:FeatureSet,MasterAccountEmail:MasterAccountEmail}' --output table

echo ""
echo "Account Summary:"
TOTAL_ACCOUNTS=$(aws organizations list-accounts --profile $PROFILE --query 'length(Accounts)' --output text)
ACTIVE_ACCOUNTS=$(aws organizations list-accounts --profile $PROFILE --query 'length(Accounts[?Status==`ACTIVE`])' --output text)
echo "Total Accounts: $TOTAL_ACCOUNTS"
echo "Active Accounts: $ACTIVE_ACCOUNTS"

# 2. ACCOUNT MANAGEMENT
echo ""
echo "👥 2. ALL ORGANIZATION ACCOUNTS"
echo "==============================="
aws organizations list-accounts --profile $PROFILE --query 'Accounts[].{Id:Id,Name:Name,Email:Email,Status:Status}' --output table

# 3. ORGANIZATIONAL STRUCTURE
echo ""
echo "🏗️ 3. ORGANIZATIONAL STRUCTURE"
echo "==============================="
ROOT_ID=$(aws organizations list-roots --profile $PROFILE --query 'Roots[0].Id' --output text)
echo "Root ID: $ROOT_ID"
echo ""
echo "Organizational Units:"
aws organizations list-organizational-units-for-parent --parent-id "$ROOT_ID" --profile $PROFILE --query 'OrganizationalUnits[].{Id:Id,Name:Name}' --output table

# Show accounts in each OU
echo ""
echo "Account Distribution by OU:"
for ou in $(aws organizations list-organizational-units-for-parent --parent-id "$ROOT_ID" --profile $PROFILE --query 'OrganizationalUnits[].Id' --output text); do
    OU_NAME=$(aws organizations describe-organizational-unit --organizational-unit-id "$ou" --profile $PROFILE --query 'OrganizationalUnit.Name' --output text)
    echo ""
    echo "OU: $OU_NAME ($ou)"
    aws organizations list-accounts-for-parent --parent-id "$ou" --profile $PROFILE --query 'Accounts[].{Id:Id,Name:Name}' --output table 2>/dev/null || echo "  No accounts in this OU"
done

# 4. SERVICE CONTROL POLICIES
echo ""
echo "🔒 4. SERVICE CONTROL POLICIES (SCPs)"
echo "====================================="
aws organizations list-policies --filter SERVICE_CONTROL_POLICY --profile $PROFILE --query 'Policies[].{Id:Id,Name:Name,Description:Description}' --output table

# 5. TRUSTED SERVICES
echo ""
echo "🔧 5. ENABLED AWS SERVICES"
echo "========================="
echo "Trusted AWS Services in Organization:"
aws organizations list-aws-service-access-for-organization --profile $PROFILE --query 'EnabledServicePrincipals[].ServicePrincipal' --output table | head -15

# 6. COST OVERVIEW (if available)
echo ""
echo "💰 6. COST OVERVIEW (Current Month)"
echo "==================================="
echo "Getting cost data for current month..."
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date -d 'next month' +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=LINKED_ACCOUNT \
  --profile $PROFILE \
  --query 'ResultsByTime[0].Groups[].{Account:Keys[0],Cost:Metrics.BlendedCost.Amount}' \
  --output table 2>/dev/null || echo "Cost Explorer data not available (may need to be enabled)"

# 7. MANAGEMENT ACTIONS MENU
echo ""
echo "🛠️ 7. AVAILABLE MANAGEMENT ACTIONS"
echo "=================================="
echo ""
echo "Account Management:"
echo "  - Create new account: aws organizations create-account --profile $PROFILE"
echo "  - Move account to OU: aws organizations move-account --profile $PROFILE"
echo ""
echo "OU Management:"
echo "  - Create new OU: aws organizations create-organizational-unit --profile $PROFILE"
echo "  - List accounts in OU: aws organizations list-accounts-for-parent --profile $PROFILE"
echo ""
echo "SCP Management:"
echo "  - Create SCP: aws organizations create-policy --type SERVICE_CONTROL_POLICY --profile $PROFILE"
echo "  - Attach SCP: aws organizations attach-policy --profile $PROFILE"
echo ""
echo "Cross-Account Access:"
echo "  - Assume role in account: aws sts assume-role --profile $PROFILE"
echo "  - Test account access: aws sts get-caller-identity --profile [account-profile]"

echo ""
echo "📋 QUICK REFERENCE COMMANDS"
echo "==========================="
echo ""
echo "# List all accounts:"
echo "aws organizations list-accounts --profile $PROFILE --output table"
echo ""
echo "# Create new account:"
echo "aws organizations create-account --account-name 'New Account' --email 'email@domain.com' --profile $PROFILE"
echo ""
echo "# Check billing for specific account:"
echo "aws ce get-cost-and-usage --time-period Start=2024-12-01,End=2024-12-31 --granularity MONTHLY --metrics BlendedCost --group-by Type=DIMENSION,Key=LINKED_ACCOUNT --profile $PROFILE"
echo ""
echo "# Assume role in member account:"
echo "aws sts assume-role --role-arn 'arn:aws:iam::ACCOUNT-ID:role/OrganizationAccountAccessRole' --role-session-name 'OrgAdmin' --profile $PROFILE"

echo ""
echo "✅ Dashboard refresh complete - $(date)"

