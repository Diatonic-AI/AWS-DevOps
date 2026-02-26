#!/bin/bash

# Script to fix OrganizationAccountAccessRole trust policies
# Run this script with root credentials for each account

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Fixing OrganizationAccountAccessRole Trust Policies ===${NC}"
echo

# Trust policy that allows both root and dfortini-local user
cat > /tmp/updated-trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::313476888312:root",
                    "arn:aws:iam::313476888312:user/dfortini-local",
                    "arn:aws:iam::313476888312:user/CentralizedAdminUser"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

echo -e "${YELLOW}You need to configure AWS profiles for each target account with root credentials:${NC}"
echo
echo "For account 824156498500 (Diatonic Online):"
echo "  aws configure --profile root-824"
echo "  Access Key ID: [Your root access key for account 824]"
echo "  Secret Access Key: [Your root secret key for account 824]"
echo "  Default region: us-east-2"
echo
echo "For account 842990485193 (Diatonic AI):"
echo "  aws configure --profile root-842"
echo "  Access Key ID: [Your root access key for account 842]"
echo "  Secret Access Key: [Your root secret key for account 842]"
echo "  Default region: us-east-2"
echo
