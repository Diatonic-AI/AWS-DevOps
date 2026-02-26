#!/bin/bash

echo "🔧 Fixing OrganizationAccountAccessRole trust policies in all member accounts..."
echo ""

# Get list of all member accounts (excluding management account)
MEMBER_ACCOUNTS=$(aws organizations list-accounts --profile aws-root --query 'Accounts[?Id!=`313476888312`].{Id:Id,Name:Name}' --output json)

echo "Member accounts found:"
echo "$MEMBER_ACCOUNTS" | jq -r '.[] | "- \(.Id) (\(.Name))"'
echo ""

# Trust policy that allows management account access
cat > /tmp/updated-org-trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::313476888312:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

echo "Updated trust policy:"
cat /tmp/updated-org-trust-policy.json
echo ""

# Function to attempt trust policy update
update_account_trust() {
    local account_id=$1
    local account_name=$2
    
    echo "Attempting to update trust policy for $account_id ($account_name)..."
    
    # Try to assume the existing OrganizationAccountAccessRole and then update it
    if CREDENTIALS=$(aws sts assume-role \
        --role-arn "arn:aws:iam::$account_id:role/OrganizationAccountAccessRole" \
        --role-session-name "UpdateTrustPolicy" \
        --profile aws-root \
        --query 'Credentials' \
        --output json 2>/dev/null); then
        
        echo "✅ Successfully assumed role in $account_id"
        
        # Extract credentials
        ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.AccessKeyId')
        SECRET_KEY=$(echo "$CREDENTIALS" | jq -r '.SecretAccessKey')
        SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.SessionToken')
        
        # Update the trust policy using the assumed role credentials
        AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
        AWS_SECRET_ACCESS_KEY="$SECRET_KEY" \
        AWS_SESSION_TOKEN="$SESSION_TOKEN" \
        aws iam update-assume-role-policy \
            --role-name OrganizationAccountAccessRole \
            --policy-document file:///tmp/updated-org-trust-policy.json
        
        if [ $? -eq 0 ]; then
            echo "✅ Trust policy updated successfully for $account_id"
        else
            echo "❌ Failed to update trust policy for $account_id"
        fi
    else
        echo "❌ Cannot assume role in $account_id - trust policy may need manual update"
    fi
    echo ""
}

# Process each member account
echo "$MEMBER_ACCOUNTS" | jq -r '.[] | "\(.Id) \(.Name)"' | while read account_id account_name; do
    update_account_trust "$account_id" "$account_name"
done

echo "🎯 Trust policy update complete!"
echo ""
echo "Testing updated access:"
echo "aws sts get-caller-identity --profile online-824"
echo "aws sts get-caller-identity --profile mgmt-842"

