#!/bin/bash
# Clean up Route53 records before deleting hosted zone
set -euo pipefail

HOSTED_ZONE_ID="Z032094313J9CQ17JQ2OQ"

echo "🗑️ Cleaning up Route53 records in hosted zone: $HOSTED_ZONE_ID"

# Create change batch to delete all A records
cat > /tmp/route53_delete_batch.json << 'EOF'
{
    "Changes": [
        {
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "diatonic.ai.",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z2FDTNDATAQYW2",
                    "DNSName": "d34iz6fjitwuax.cloudfront.net.",
                    "EvaluateTargetHealth": false
                }
            }
        },
        {
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "app.diatonic.ai.",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z2FDTNDATAQYW2",
                    "DNSName": "d34iz6fjitwuax.cloudfront.net.",
                    "EvaluateTargetHealth": false
                }
            }
        },
        {
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "dev.diatonic.ai.",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z2FDTNDATAQYW2",
                    "DNSName": "d34iz6fjitwuax.cloudfront.net.",
                    "EvaluateTargetHealth": false
                }
            }
        },
        {
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "admin.dev.diatonic.ai.",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z2FDTNDATAQYW2",
                    "DNSName": "d34iz6fjitwuax.cloudfront.net.",
                    "EvaluateTargetHealth": false
                }
            }
        },
        {
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "app.dev.diatonic.ai.",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z2FDTNDATAQYW2",
                    "DNSName": "d34iz6fjitwuax.cloudfront.net.",
                    "EvaluateTargetHealth": false
                }
            }
        },
        {
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "www.dev.diatonic.ai.",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z2FDTNDATAQYW2",
                    "DNSName": "d34iz6fjitwuax.cloudfront.net.",
                    "EvaluateTargetHealth": false
                }
            }
        },
        {
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "www.diatonic.ai.",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z2FDTNDATAQYW2",
                    "DNSName": "d34iz6fjitwuax.cloudfront.net.",
                    "EvaluateTargetHealth": false
                }
            }
        }
    ]
}
EOF

echo "📤 Submitting Route53 record deletion batch..."
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch file:///tmp/route53_delete_batch.json \
    --query 'ChangeInfo.Id' --output text)

echo "✅ Change submitted: $CHANGE_ID"

echo "⏳ Waiting for Route53 changes to propagate..."
aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"

echo "✅ Route53 changes propagated"

# Clean up temporary file
rm -f /tmp/route53_delete_batch.json

echo "🗑️ Now deleting the hosted zone..."
aws route53 delete-hosted-zone --id "$HOSTED_ZONE_ID"

echo "✅ Route53 hosted zone deleted successfully!"
echo "💰 You're now saving ~$0.50+/month on Route53 costs"
