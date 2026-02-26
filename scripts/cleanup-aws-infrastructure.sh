#!/bin/bash
# AWS Infrastructure Cleanup - Route53 and CloudFront
# This script safely removes the old AWS infrastructure after Cloudflare migration
set -euo pipefail

echo "🧹 AWS Infrastructure Cleanup - Post Cloudflare Migration"
echo "========================================================="

# Configuration
ROUTE53_HOSTED_ZONE_ID="Z032094313J9CQ17JQ2OQ"
CLOUDFRONT_DISTRIBUTION_1="EB3GDEPQ1RC9T"  # Dev environment
CLOUDFRONT_DISTRIBUTION_2="EQKQIA54WHS82"  # Production environment

echo "📋 Resources to be cleaned up:"
echo "  - Route53 Hosted Zone: $ROUTE53_HOSTED_ZONE_ID (diatonic.ai)"
echo "  - CloudFront Distribution 1: $CLOUDFRONT_DISTRIBUTION_1 (dev environment)"
echo "  - CloudFront Distribution 2: $CLOUDFRONT_DISTRIBUTION_2 (production environment)"

# Function to safely delete Route53 hosted zone
cleanup_route53() {
    echo ""
    echo "🗑️  Cleaning up Route53 hosted zone..."
    
    # First, list all records in the hosted zone
    echo "📋 Listing current Route53 records..."
    aws route53 list-resource-record-sets --hosted-zone-id "$ROUTE53_HOSTED_ZONE_ID" \
        --query 'ResourceRecordSets[?Type!=`NS` && Type!=`SOA`]' --output table
    
    # Get all non-essential records (excluding NS and SOA)
    local records_to_delete=$(aws route53 list-resource-record-sets --hosted-zone-id "$ROUTE53_HOSTED_ZONE_ID" \
        --query 'ResourceRecordSets[?Type!=`NS` && Type!=`SOA`]' --output json)
    
    # Create change batch to delete all records
    if [[ "$records_to_delete" != "[]" ]]; then
        echo "🗑️  Deleting Route53 records..."
        
        # Create a temporary file with delete changes
        local change_batch_file="/tmp/route53_delete_changes_$$.json"
        echo "{\"Changes\":[" > "$change_batch_file"
        
        local first_record=true
        echo "$records_to_delete" | jq -c '.[]' | while read -r record; do
            if [[ "$first_record" == "true" ]]; then
                first_record=false
            else
                echo "," >> "$change_batch_file"
            fi
            
            echo "{\"Action\":\"DELETE\",\"ResourceRecordSet\":$record}" >> "$change_batch_file"
        done
        
        echo "]}" >> "$change_batch_file"
        
        # Execute the change batch
        echo "📤 Submitting Route53 record deletions..."
        local change_id=$(aws route53 change-resource-record-sets \
            --hosted-zone-id "$ROUTE53_HOSTED_ZONE_ID" \
            --change-batch file://"$change_batch_file" \
            --query 'ChangeInfo.Id' --output text)
        
        echo "  ✅ Change submitted: $change_id"
        
        # Wait for changes to propagate
        echo "⏳ Waiting for Route53 changes to propagate..."
        aws route53 wait resource-record-sets-changed --id "$change_id"
        echo "  ✅ Route53 changes propagated"
        
        # Clean up temporary file
        rm -f "$change_batch_file"
    else
        echo "  ℹ️  No additional records to delete"
    fi
    
    # Now delete the hosted zone
    echo "🗑️  Deleting Route53 hosted zone..."
    aws route53 delete-hosted-zone --id "$ROUTE53_HOSTED_ZONE_ID"
    echo "  ✅ Route53 hosted zone deleted: $ROUTE53_HOSTED_ZONE_ID"
    echo "  💰 Cost savings: ~$0.50/month"
}

# Function to disable CloudFront distribution
disable_cloudfront_distribution() {
    local distribution_id="$1"
    local distribution_name="$2"
    
    echo ""
    echo "🔄 Disabling CloudFront distribution: $distribution_id ($distribution_name)..."
    
    # Get current distribution config
    echo "📋 Getting current distribution configuration..."
    local config_file="/tmp/cloudfront_config_${distribution_id}.json"
    aws cloudfront get-distribution-config --id "$distribution_id" > "$config_file"
    
    # Extract the current ETag and config
    local etag=$(cat "$config_file" | jq -r '.ETag')
    local distribution_config=$(cat "$config_file" | jq '.DistributionConfig')
    
    # Modify config to disable the distribution
    local updated_config=$(echo "$distribution_config" | jq '.Enabled = false')
    
    # Save the updated config
    echo "$updated_config" > "${config_file}.updated"
    
    echo "🔄 Submitting distribution disable request..."
    aws cloudfront update-distribution \
        --id "$distribution_id" \
        --distribution-config file://"${config_file}.updated" \
        --if-match "$etag"
    
    echo "  ✅ CloudFront distribution disable request submitted: $distribution_id"
    echo "  ⏳ Distribution will be disabled (this may take 15-20 minutes)"
    
    # Clean up temporary files
    rm -f "$config_file" "${config_file}.updated"
}

# Function to check CloudFront distribution status
check_cloudfront_status() {
    local distribution_id="$1"
    
    local status=$(aws cloudfront get-distribution --id "$distribution_id" \
        --query 'Distribution.DistributionConfig.Enabled' --output text)
    
    echo "CloudFront $distribution_id status: $status"
}

# Function to delete CloudFront distribution (only after it's disabled)
delete_cloudfront_distribution() {
    local distribution_id="$1"
    local distribution_name="$2"
    
    echo ""
    echo "🗑️  Attempting to delete CloudFront distribution: $distribution_id ($distribution_name)..."
    
    # Check if distribution is disabled
    local enabled=$(aws cloudfront get-distribution --id "$distribution_id" \
        --query 'Distribution.DistributionConfig.Enabled' --output text)
    
    if [[ "$enabled" == "true" ]]; then
        echo "  ⚠️  Distribution is still enabled. Cannot delete until disabled."
        echo "     Run this script again after the distribution is fully disabled (15-20 minutes)."
        return 1
    fi
    
    # Get current ETag
    local etag=$(aws cloudfront get-distribution --id "$distribution_id" --query 'ETag' --output text)
    
    # Delete the distribution
    echo "🗑️  Deleting CloudFront distribution..."
    aws cloudfront delete-distribution --id "$distribution_id" --if-match "$etag"
    
    echo "  ✅ CloudFront distribution deleted: $distribution_id"
    echo "  💰 Cost savings: ~$15-30/month per distribution"
}

# Main execution
echo ""
echo "🚦 Starting AWS Infrastructure Cleanup..."
echo ""

# Confirm current Cloudflare status first
echo "🔍 Verifying Cloudflare is working properly..."
if dig +short diatonic.ai @1.1.1.1 | grep -E "(104\.21\.|172\.67\.)" >/dev/null; then
    echo "  ✅ Cloudflare DNS is working correctly"
else
    echo "  ❌ Cloudflare DNS not detected! Aborting cleanup for safety."
    exit 1
fi

# Test HTTPS connectivity
if curl -s -I https://diatonic.ai | grep -q "server: cloudflare"; then
    echo "  ✅ Cloudflare HTTPS is working correctly"
else
    echo "  ❌ Cloudflare HTTPS not detected! Aborting cleanup for safety."
    exit 1
fi

echo ""
echo "✅ Cloudflare migration verified - safe to proceed with cleanup"

# Step 1: Clean up Route53
echo ""
read -p "🤔 Delete Route53 hosted zone? This will save ~$0.50/month (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cleanup_route53
else
    echo "  ⏭️  Skipping Route53 cleanup"
fi

# Step 2: Disable CloudFront distributions
echo ""
read -p "🤔 Disable CloudFront distributions? This will save ~$30-60/month (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    disable_cloudfront_distribution "$CLOUDFRONT_DISTRIBUTION_1" "dev-environment"
    disable_cloudfront_distribution "$CLOUDFRONT_DISTRIBUTION_2" "production-environment"
    
    echo ""
    echo "⏳ CloudFront distributions are being disabled..."
    echo "   This process takes 15-20 minutes to complete."
    echo "   Run this script again later to delete the distributions completely."
else
    echo "  ⏭️  Skipping CloudFront cleanup"
fi

# Step 3: Check if we can delete CloudFront distributions
echo ""
echo "🔍 Checking CloudFront distribution status..."
check_cloudfront_status "$CLOUDFRONT_DISTRIBUTION_1"
check_cloudfront_status "$CLOUDFRONT_DISTRIBUTION_2"

# Offer to delete if disabled
local both_disabled=true
if aws cloudfront get-distribution --id "$CLOUDFRONT_DISTRIBUTION_1" --query 'Distribution.DistributionConfig.Enabled' --output text | grep -q "true"; then
    both_disabled=false
fi
if aws cloudfront get-distribution --id "$CLOUDFRONT_DISTRIBUTION_2" --query 'Distribution.DistributionConfig.Enabled' --output text | grep -q "true"; then
    both_disabled=false
fi

if [[ "$both_disabled" == "true" ]]; then
    echo ""
    read -p "🗑️  Both distributions are disabled. Delete them now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        delete_cloudfront_distribution "$CLOUDFRONT_DISTRIBUTION_1" "dev-environment"
        delete_cloudfront_distribution "$CLOUDFRONT_DISTRIBUTION_2" "production-environment"
    fi
fi

echo ""
echo "📊 Cleanup Summary"
echo "=================="
echo "✅ Cloudflare migration: Complete and verified"

# Check what was cleaned up
if ! aws route53 get-hosted-zone --id "$ROUTE53_HOSTED_ZONE_ID" >/dev/null 2>&1; then
    echo "✅ Route53 hosted zone: Deleted (saving ~$0.50/month)"
else
    echo "⏭️  Route53 hosted zone: Still active"
fi

# Check CloudFront status
echo "📊 CloudFront distributions:"
for dist_id in "$CLOUDFRONT_DISTRIBUTION_1" "$CLOUDFRONT_DISTRIBUTION_2"; do
    if aws cloudfront get-distribution --id "$dist_id" >/dev/null 2>&1; then
        local status=$(aws cloudfront get-distribution --id "$dist_id" --query 'Distribution.DistributionConfig.Enabled' --output text)
        if [[ "$status" == "false" ]]; then
            echo "  🔄 $dist_id: Disabled (will save ~$15-30/month when deleted)"
        else
            echo "  ⚠️  $dist_id: Still enabled"
        fi
    else
        echo "  ✅ $dist_id: Deleted (saving ~$15-30/month)"
    fi
done

echo ""
echo "💰 Estimated Monthly Savings:"
echo "  - Route53 DNS queries: $0.50+"
echo "  - CloudFront distributions: $30-60"
echo "  - Total estimated savings: $30-60+ per month"

echo ""
echo "🎉 AWS Infrastructure Cleanup Completed!"
echo ""
echo "🔮 Next Steps (if CloudFront distributions are still disabling):"
echo "   1. Wait 15-20 minutes for distributions to fully disable"
echo "   2. Run this script again to delete the disabled distributions"
echo "   3. Monitor your AWS bill for cost reductions"

echo ""
echo "✅ Your Cloudflare migration is complete and AWS cleanup is in progress!"
