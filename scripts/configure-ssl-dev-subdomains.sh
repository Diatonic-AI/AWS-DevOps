#!/bin/bash
# SSL Configuration and Automation for Dev Subdomains
set -euo pipefail

CLOUDFLARE_API_TOKEN="TlBm4S8Ph468j_y6d2PsW7iurxUlg9FuMWi_XoTx"
ZONE_ID="f889715fdbadcf662ea496b8e40ee6eb"

echo "🔒 Configuring SSL for Dev Subdomains"
echo "Zone ID: $ZONE_ID"

# Dev subdomains that need SSL configuration
DEV_SUBDOMAINS=(
    "admin.dev.diatonic.ai"
    "api.dev.diatonic.ai" 
    "app.dev.diatonic.ai"
    "local.dev.diatonic.ai"
    "www.dev.diatonic.ai"
)

# Function to check SSL certificate status
check_ssl_status() {
    local domain="$1"
    echo "🔍 Checking SSL status for $domain..."
    
    # Test SSL connection
    if timeout 10 openssl s_client -connect "${domain}:443" -servername "$domain" </dev/null 2>/dev/null | grep -q "CONNECTED"; then
        echo "  ✅ SSL connection successful"
        
        # Get certificate details
        local cert_info=$(timeout 10 openssl s_client -connect "${domain}:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null || echo "")
        
        if [[ -n "$cert_info" ]]; then
            echo "  📜 Certificate details:"
            echo "$cert_info" | sed 's/^/    /'
        fi
    else
        echo "  ❌ SSL connection failed or timeout"
        return 1
    fi
}

# Function to verify DNS and SSL readiness
verify_domain_readiness() {
    local domain="$1"
    echo "🌐 Verifying domain readiness: $domain"
    
    # Check DNS resolution
    local ip_addresses=$(dig +short "$domain" @1.1.1.1)
    if [[ -n "$ip_addresses" ]]; then
        echo "  ✅ DNS resolves to: $ip_addresses"
    else
        echo "  ❌ DNS resolution failed"
        return 1
    fi
    
    # Check if proxied through Cloudflare
    if echo "$ip_addresses" | grep -E "(104\.21\.|172\.67\.|198\.41\.|197\.234\.|188\.114\.)" > /dev/null; then
        echo "  ✅ Proxied through Cloudflare"
    else
        echo "  ⚠️  Not detected as proxied through Cloudflare"
    fi
}

# Function to enable HTTP Strict Transport Security (HSTS)
configure_hsts() {
    local domain="$1"
    echo "🛡️  Configuring HSTS for better SSL security..."
    
    # Note: HSTS is configured at the zone level in Cloudflare
    # This function documents the configuration that should be in place
    echo "  📋 HSTS should be enabled at zone level with:"
    echo "    - max-age: 31536000 (1 year)"
    echo "    - includeSubDomains: true"
    echo "    - preload: false (optional)"
}

# Function to test HTTPS redirect
test_https_redirect() {
    local domain="$1"
    echo "🔄 Testing HTTP to HTTPS redirect for $domain..."
    
    local response=$(curl -s -I "http://$domain" -m 10 2>/dev/null | head -1 || echo "")
    if echo "$response" | grep -q "301\|302"; then
        echo "  ✅ HTTP redirects to HTTPS"
    else
        echo "  ⚠️  HTTP redirect not detected - response: $response"
    fi
}

# Function to wait for SSL certificate provisioning
wait_for_ssl_provisioning() {
    local domain="$1"
    local max_wait=300  # 5 minutes
    local wait_time=0
    local interval=30   # Check every 30 seconds
    
    echo "⏳ Waiting for SSL certificate provisioning for $domain..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        if check_ssl_status "$domain" 2>/dev/null; then
            echo "  ✅ SSL certificate is ready!"
            return 0
        fi
        
        echo "  ⏳ Waiting... ($wait_time/${max_wait}s)"
        sleep $interval
        wait_time=$((wait_time + interval))
    done
    
    echo "  ⚠️  SSL certificate not ready after ${max_wait}s"
    return 1
}

# Function to create page rule for dev subdomain optimization
create_dev_page_rule() {
    local subdomain="$1"
    echo "📋 Creating page rule for $subdomain optimization..."
    
    local page_rule_data=$(cat <<EOF
{
  "targets": [
    {
      "target": "url",
      "constraint": {
        "operator": "matches",
        "value": "*.${subdomain}/*"
      }
    }
  ],
  "actions": [
    {
      "id": "ssl",
      "value": "full"
    },
    {
      "id": "always_use_https",
      "value": true
    },
    {
      "id": "security_level",
      "value": "medium"
    },
    {
      "id": "cache_level",
      "value": "standard"
    }
  ],
  "priority": 2,
  "status": "active"
}
EOF
    )
    
    # Note: This would require additional API permissions
    echo "  📝 Page rule configuration prepared for $subdomain"
}

echo "🚀 Starting SSL configuration for dev subdomains..."

# Check current zone SSL settings
echo "🔍 Checking current zone SSL settings..."
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/ssl" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" | \
    jq '.result | {ssl: .value}' 2>/dev/null || echo "Could not retrieve SSL settings"

curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/always_use_https" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" | \
    jq '.result | {always_use_https: .value}' 2>/dev/null || echo "Could not retrieve HTTPS redirect settings"

# Process each dev subdomain
for subdomain in "${DEV_SUBDOMAINS[@]}"; do
    echo ""
    echo "🔧 Processing: $subdomain"
    echo "================================="
    
    # Verify domain is ready
    if verify_domain_readiness "$subdomain"; then
        echo "  ✅ Domain is ready for SSL configuration"
        
        # Check current SSL status
        if check_ssl_status "$subdomain"; then
            echo "  ✅ SSL is already working for $subdomain"
            
            # Test HTTPS redirect
            test_https_redirect "$subdomain"
            
        else
            echo "  ⏳ SSL not ready yet, waiting for certificate provisioning..."
            
            # Wait for SSL provisioning
            if wait_for_ssl_provisioning "$subdomain"; then
                echo "  ✅ SSL provisioning completed for $subdomain"
                test_https_redirect "$subdomain"
            else
                echo "  ❌ SSL provisioning failed for $subdomain"
                echo "    This may require manual intervention or additional wait time"
            fi
        fi
        
        # Configure HSTS (informational)
        configure_hsts "$subdomain"
        
        # Create page rule (informational)
        create_dev_page_rule "$subdomain"
        
    else
        echo "  ❌ Domain $subdomain is not ready for SSL configuration"
        echo "    Please ensure DNS is properly configured and propagated"
    fi
    
    echo "================================="
done

echo ""
echo "📊 SSL Configuration Summary"
echo "============================="

# Generate final status report
for subdomain in "${DEV_SUBDOMAINS[@]}"; do
    echo -n "$subdomain: "
    if check_ssl_status "$subdomain" >/dev/null 2>&1; then
        echo "✅ SSL Working"
    else
        echo "❌ SSL Not Ready"
    fi
done

echo ""
echo "🎯 Next Steps:"
echo "1. Monitor SSL certificate provisioning (may take 5-15 minutes)"
echo "2. Test all dev subdomains for proper HTTPS functionality"
echo "3. Configure any application-specific SSL settings"
echo "4. Set up monitoring for SSL certificate renewals"

echo ""
echo "🔍 Manual Testing Commands:"
echo "curl -I https://admin.dev.diatonic.ai"
echo "curl -I https://api.dev.diatonic.ai" 
echo "curl -I https://app.dev.diatonic.ai"
echo "curl -I https://local.dev.diatonic.ai"
echo "curl -I https://www.dev.diatonic.ai"

echo ""
echo "✅ SSL Configuration Script Completed"
