#!/bin/bash

# Manual trust policy update script
# Run this with individual account credentials

echo "=== Manual Trust Policy Update Instructions ==="
echo ""
echo "Since we cannot assume roles from root account, you need to:"
echo ""
echo "1. For Account 824156498500 (Diatonic Online):"
echo "   - Log into AWS Console as root user for this account"
echo "   - Go to IAM > Roles > OrganizationAccountAccessRole"
echo "   - Click 'Trust relationships' tab"
echo "   - Click 'Edit trust policy'"
echo "   - Replace with the contents of /tmp/org-role-trust-policy.json"
echo ""
echo "2. For Account 842990485193 (Diatonic AI):"
echo "   - Log into AWS Console as root user for this account"
echo "   - Go to IAM > Roles > OrganizationAccountAccessRole"
echo "   - Click 'Trust relationships' tab"
echo "   - Click 'Edit trust policy'"
echo "   - Replace with the contents of /tmp/org-role-trust-policy.json"
echo ""
echo "Trust policy content:"
cat /tmp/org-role-trust-policy.json
echo ""
echo "After updating both accounts, test with:"
echo "  aws sts get-caller-identity --profile online-824"
echo "  aws sts get-caller-identity --profile mgmt-842"
