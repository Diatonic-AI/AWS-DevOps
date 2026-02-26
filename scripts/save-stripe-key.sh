#!/bin/bash
#
# Save Stripe API Key to AWS Secrets Manager
# This script securely prompts for your Stripe key and saves it
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Save Stripe API Key to AWS Secrets Manager${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Please enter your Stripe Secret API key${NC}"
echo -e "${YELLOW}(starts with sk_live_ for production or sk_test_ for testing)${NC}"
echo ""
read -s -p "Stripe API Key: " STRIPE_KEY
echo ""
echo ""

if [[ -z "$STRIPE_KEY" ]]; then
    echo -e "${YELLOW}No key provided. Exiting.${NC}"
    exit 1
fi

# Validate key format
if [[ ! "$STRIPE_KEY" =~ ^sk_(live|test)_ ]]; then
    echo -e "${YELLOW}Warning: Key doesn't start with sk_live_ or sk_test_${NC}"
    echo -e "Are you sure this is correct? (y/n)"
    read -r confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Exiting."
        exit 1
    fi
fi

echo -e "${BLUE}Saving to AWS Secrets Manager...${NC}"

# Create or update the secret
aws secretsmanager create-secret \
    --name client-billing/stripe-api-key \
    --secret-string "{\"apiKey\":\"$STRIPE_KEY\"}" \
    --region us-east-1 \
    2>&1 | grep -v "ResourceExistsException" || {
        echo -e "${YELLOW}Secret already exists, updating...${NC}"
        aws secretsmanager update-secret \
            --secret-id client-billing/stripe-api-key \
            --secret-string "{\"apiKey\":\"$STRIPE_KEY\"}" \
            --region us-east-1 > /dev/null 2>&1
    }

echo ""
echo -e "${GREEN}✅ Stripe API key saved successfully!${NC}"
echo ""
echo -e "${BLUE}Secret Name:${NC} client-billing/stripe-api-key"
echo -e "${BLUE}Region:${NC} us-east-1"
echo ""
echo -e "${YELLOW}Next step:${NC} Run deployment script"
echo "  ./scripts/deploy-client-billing-portal.sh"
echo ""

# Clear the variable for security
unset STRIPE_KEY
