#!/bin/bash
# Fix Cloudflare DNS Records to Point to Load Balancer
set -euo pipefail

CLOUDFLARE_API_TOKEN="TlBm4S8Ph468j_y6d2PsW7iurxUlg9FuMWi_XoTx"
ZONE_ID="f889715fdbadcf662ea496b8e40ee6eb"
LOAD_BALANCER_IP="52.14.104.246"  # Primary load balancer IP
LOAD_BALANCER_IP_2="13.59.40.250"  # Secondary load balancer IP

echo "🔧 Fixing Cloudflare DNS Records to Point to Load Balancer"
echo "Zone ID: $ZONE_ID"
echo "Target IP: $LOAD_BALANCER_IP"

# Function to update/create DNS record
update_dns_record() {
    local name="$1"
    local content="$2"
    local proxied="${3:-true}"
    
    echo "📋 Updating DNS record: $name -> $content (proxied: $proxied)"
    
    # Get existing record ID if it exists
    local record_data=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$name&type=A" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local record_id=$(echo "$record_data" | jq -r '.result[0].id // empty')
    
    if [[ -n "$record_id" && "$record_id" != "null" ]]; then
        # Update existing record
        echo "  ↻ Updating existing record ID: $record_id"
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$name\",\"content\":\"$content\",\"proxied\":$proxied}" \
            | jq '.success'
    else
        # Create new record
        echo "  + Creating new record"
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$name\",\"content\":\"$content\",\"proxied\":$proxied}" \
            | jq '.success'
    fi
}

# Function to delete CNAME record and create A record
replace_cname_with_a() {
    local name="$1"
    local content="$2"
    local proxied="${3:-true}"
    
    echo "📋 Replacing CNAME with A record: $name -> $content"
    
    # Get existing CNAME record ID
    local record_data=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$name&type=CNAME" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local record_id=$(echo "$record_data" | jq -r '.result[0].id // empty')
    
    if [[ -n "$record_id" && "$record_id" != "null" ]]; then
        # Delete existing CNAME record
        echo "  - Deleting CNAME record ID: $record_id"
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" > /dev/null
        
        sleep 2  # Brief delay to ensure deletion completes
    fi
    
    # Create new A record
    echo "  + Creating new A record"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$name\",\"content\":\"$content\",\"proxied\":$proxied}" \
        | jq -r '.success'
}

echo "🎯 Updating main domains to point to load balancer..."

# Main domains - replace CloudFront CNAMEs with Load Balancer A records
replace_cname_with_a "diatonic.ai" "$LOAD_BALANCER_IP" true
replace_cname_with_a "www.diatonic.ai" "$LOAD_BALANCER_IP" true
replace_cname_with_a "app.diatonic.ai" "$LOAD_BALANCER_IP" true
replace_cname_with_a "api.diatonic.ai" "$LOAD_BALANCER_IP" true

echo "🔧 Updating dev environment domains..."

# Dev domains - replace CloudFront CNAMEs with Load Balancer A records
replace_cname_with_a "dev.diatonic.ai" "$LOAD_BALANCER_IP" true
replace_cname_with_a "www.dev.diatonic.ai" "$LOAD_BALANCER_IP" true
replace_cname_with_a "app.dev.diatonic.ai" "$LOAD_BALANCER_IP" true
replace_cname_with_a "api.dev.diatonic.ai" "$LOAD_BALANCER_IP" true
replace_cname_with_a "local.dev.diatonic.ai" "$LOAD_BALANCER_IP" true

# Admin dev domain - was pointing to diatonic.ai CNAME, now point to load balancer
replace_cname_with_a "admin.dev.diatonic.ai" "$LOAD_BALANCER_IP" true

echo "✅ DNS records updated successfully!"
echo ""
echo "🧪 Test DNS propagation with:"
echo "  dig diatonic.ai @1.1.1.1"
echo "  dig www.diatonic.ai @1.1.1.1"
echo "  dig app.diatonic.ai @1.1.1.1"
echo ""
echo "Expected result: $LOAD_BALANCER_IP"
