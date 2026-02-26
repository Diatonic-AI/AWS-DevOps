#!/bin/bash
# Fix diatonic.ai root domain to point to same CloudFront as www.diatonic.ai
set -euo pipefail

CLOUDFLARE_API_TOKEN="TlBm4S8Ph468j_y6d2PsW7iurxUlg9FuMWi_XoTx"
ZONE_ID="f889715fdbadcf662ea496b8e40ee6eb"
CLOUDFRONT_DOMAIN="dxz4p4iipx5lm.cloudfront.net"  # Same as www.diatonic.ai

echo "🔧 Fixing diatonic.ai root domain to point to working CloudFront distribution"
echo "Zone ID: $ZONE_ID"
echo "Target CloudFront: $CLOUDFRONT_DOMAIN"

# Function to replace A record with CNAME record
replace_a_with_cname() {
    local name="$1"
    local content="$2"
    local proxied="${3:-false}"  # Don't proxy CNAME to CloudFront
    
    echo "📋 Replacing A record with CNAME: $name -> $content"
    
    # Get existing A record ID
    local record_data=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$name&type=A" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local record_id=$(echo "$record_data" | jq -r '.result[0].id // empty')
    
    if [[ -n "$record_id" && "$record_id" != "null" ]]; then
        # Delete existing A record
        echo "  - Deleting A record ID: $record_id"
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" > /dev/null
        
        sleep 2  # Brief delay to ensure deletion completes
    fi
    
    # Create new CNAME record
    echo "  + Creating new CNAME record"
    local result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"CNAME\",\"name\":\"$name\",\"content\":\"$content\",\"proxied\":$proxied}")
    
    local success=$(echo "$result" | jq -r '.success')
    if [[ "$success" == "true" ]]; then
        echo "  ✅ Successfully created CNAME record"
    else
        echo "  ❌ Failed to create CNAME record"
        echo "$result" | jq '.errors[]'
    fi
}

echo "🎯 Updating root domain to point to working CloudFront distribution..."

# Fix root domain - point to same CloudFront as www
replace_a_with_cname "diatonic.ai" "$CLOUDFRONT_DOMAIN" false

echo ""
echo "✅ DNS record updated successfully!"
echo ""
echo "🧪 Test the fix:"
echo "  # Wait 1-2 minutes for DNS propagation, then test:"
echo "  curl -I https://diatonic.ai"
echo "  # Should now return the same content as www.diatonic.ai"
echo ""
echo "🌐 Both domains should now work:"
echo "  https://diatonic.ai"
echo "  https://www.diatonic.ai"
