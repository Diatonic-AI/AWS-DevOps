#!/bin/bash

echo "🎯 AUTOMATED IAM USER CREATION FOR CROSS-ACCOUNT ACCESS"
echo "========================================================"
echo ""
echo "This script will help you create IAM users in target accounts."
echo ""

# Function to create IAM user setup commands
generate_user_commands() {
    local account_id=$1
    local account_name=$2
    local profile_name=$3
    local user_name=$4
    
    echo "### Commands for Account $account_id ($account_name) ###"
    echo ""
    echo "# 1. First, configure credentials for this account:"
    echo "aws configure --profile temp-$profile_name"
    echo ""
    echo "# 2. Create IAM user with admin access:"
    echo "aws iam create-user --user-name $user_name --profile temp-$profile_name"
    echo ""
    echo "# 3. Attach administrator access policy:"
    echo "aws iam attach-user-policy \\"
    echo "  --user-name $user_name \\"
    echo "  --policy-arn 'arn:aws:iam::aws:policy/AdministratorAccess' \\"
    echo "  --profile temp-$profile_name"
    echo ""
    echo "# 4. Create access keys:"
    echo "aws iam create-access-key --user-name $user_name --profile temp-$profile_name"
    echo ""
    echo "# 5. Configure permanent profile with the new access keys:"
    echo "aws configure --profile $profile_name"
    echo ""
    echo "# 6. Test access:"
    echo "aws sts get-caller-identity --profile $profile_name"
    echo ""
    echo "=========================================================="
    echo ""
}

echo "OPTION A: Create Individual IAM Users (Recommended)"
echo "==================================================="
echo ""

# Generate commands for key accounts
generate_user_commands "824156498500" "Diatonic Online" "dfortini-824" "dfortini-admin-824"
generate_user_commands "842990485193" "Diatonic AI" "dfortini-842" "dfortini-admin-842"
generate_user_commands "916873234430" "Diatonic Dev" "dfortini-916" "dfortini-admin-916"

echo ""
echo "OPTION B: Quick Setup Using Root Console Access"
echo "==============================================="
echo ""
echo "If you have root access to the accounts, you can use AWS Console:"
echo ""
echo "1. Login to each account with root credentials"
echo "2. Go to IAM → Users → Create User"
echo "3. Username: dfortini-admin-[account-suffix]"
echo "4. Enable both console and programmatic access"
echo "5. Attach AdministratorAccess policy"
echo "6. Download the CSV with credentials"
echo "7. Configure AWS CLI profile with the credentials"
echo ""
echo ""
echo "VERIFICATION COMMANDS:"
echo "====================="
echo "aws sts get-caller-identity --profile dfortini-824"
echo "aws sts get-caller-identity --profile dfortini-842"
echo "aws sts get-caller-identity --profile dfortini-916"

