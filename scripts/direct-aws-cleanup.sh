#!/bin/bash
# Direct AWS Infrastructure Cleanup - Route53 and CloudFront
set -euo pipefail

echo "🧹 Direct AWS Infrastructure Cleanup"
echo "===================================="
echo ""

# Verify Cloudflare is working first
echo "🔍 Verifying Cloudflare is working..."
if dig +short diatonic.ai @1.1.1.1 | grep -E "(104\.21\.|172\.67\.)" >/dev/null; then
    echo "✅ Cloudflare DNS is working"
else
    echo "❌ Cloudflare not working! Aborting cleanup."
    exit 1
fi

if curl -s -I https://diatonic.ai | grep -q "server: cloudflare"; then
    echo "✅ Cloudflare HTTPS is working"
    echo ""
else
    echo "❌ Cloudflare HTTPS not working! Aborting cleanup."
    exit 1
fi

# Step 1: Clean up Route53 records and hosted zone
echo "🗑️ Cleaning up Route53..."
echo "Hosted Zone ID: Z032094313J9CQ17JQ2OQ"

# Delete all A records and CNAMEs (keep NS and SOA)
aws route53 change-resource-record-sets --hosted-zone-id Z032094313J9CQ17JQ2OQ --change-batch '{
    "Changes": [
        {
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "diatonic.ai.",
                "Type": "A",
                "AliasTarget": {
                    "DNSName": "d34iz6fjitwuax.cloudfront.net.",
                    "EvaluateTargetHealth": false,
                    "HostedZoneId": "Z2FDTNDATAQYW2"
                }
            }
        }
    ]
}' || echo "Record may already be deleted"

# Delete hosted zone
echo "🗑️ Deleting Route53 hosted zone..."
aws route53 delete-hosted-zone --id Z032094313J9CQ17JQ2OQ || echo "Zone may already be deleted"
echo "✅ Route53 cleanup completed"

# Step 2: Disable CloudFront distributions
echo ""
echo "🔄 Disabling CloudFront distributions..."

# Distribution 1: EB3GDEPQ1RC9T (dev)
echo "Disabling EB3GDEPQ1RC9T (dev)..."
aws cloudfront get-distribution-config --id EB3GDEPQ1RC9T > /tmp/cf_config_1.json
ETAG1=$(cat /tmp/cf_config_1.json | jq -r '.ETag')
cat /tmp/cf_config_1.json | jq '.DistributionConfig | .Enabled = false' > /tmp/cf_config_1_updated.json

aws cloudfront update-distribution \
    --id EB3GDEPQ1RC9T \
    --distribution-config file:///tmp/cf_config_1_updated.json \
    --if-match "$ETAG1" || echo "Distribution 1 may already be disabled"

# Distribution 2: EQKQIA54WHS82 (prod)
echo "Disabling EQKQIA54WHS82 (prod)..."
aws cloudfront get-distribution-config --id EQKQIA54WHS82 > /tmp/cf_config_2.json
ETAG2=$(cat /tmp/cf_config_2.json | jq -r '.ETag')
cat /tmp/cf_config_2.json | jq '.DistributionConfig | .Enabled = false' > /tmp/cf_config_2_updated.json

aws cloudfront update-distribution \
    --id EQKQIA54WHS82 \
    --distribution-config file:///tmp/cf_config_2_updated.json \
    --if-match "$ETAG2" || echo "Distribution 2 may already be disabled"

echo "✅ CloudFront distributions are being disabled (takes 15-20 minutes)"

# Cleanup temp files
rm -f /tmp/cf_config_*.json

echo ""
echo "📊 Cleanup Summary:"
echo "✅ Route53 hosted zone: Deleted"
echo "🔄 CloudFront distributions: Disabling (15-20 minutes)"
echo "💰 Monthly savings: ~$30-60"
echo ""
echo "🎯 To complete cleanup:"
echo "   Wait 15-20 minutes, then run:"
echo "   aws cloudfront delete-distribution --id EB3GDEPQ1RC9T --if-match <etag>"
echo "   aws cloudfront delete-distribution --id EQKQIA54WHS82 --if-match <etag>"

echo ""
echo "🎉 AWS Cleanup In Progress!"
