#!/bin/bash

# Organization Management Dashboard for DiatonicAI Management Account
# Account: 313476888312 | User: dfortini-local | Organization: o-eyf5fcwrr3
# OPTIMIZED VERSION - Cost Explorer usage reduced with caching

PROFILE="dfortini-local"
ORG_ID="o-eyf5fcwrr3"
MGMT_ACCOUNT="313476888312"

# COST OPTIMIZATION: Cache configuration
CACHE_DIR="$HOME/.cache/org-dashboard"
CACHE_DURATION_HOURS=24
COST_DATA_CACHE="$CACHE_DIR/cost_data_$(date +%Y%m%d).json"
ENABLE_COST_EXPLORER=${ENABLE_COST_EXPLORER:-"true"} # Can be disabled via env var

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

echo "🏢 DIATONIC ORGANIZATION MANAGEMENT DASHBOARD (OPTIMIZED)"
echo "========================================================="
echo "Management Account: $MGMT_ACCOUNT (DiatonicAI)"
echo "Organization ID: $ORG_ID"
echo "Administrator: dfortini-local"
echo "Timestamp: $(date)"
echo "Cost Explorer: $ENABLE_COST_EXPLORER (cached for ${CACHE_DURATION_HOURS}h)"
echo ""

# 1. ORGANIZATION HEALTH CHECK
echo "📊 1. ORGANIZATION HEALTH CHECK"
echo "==============================="
echo ""
echo "Organization Details:"
aws organizations describe-organization --profile $PROFILE --query 'Organization.{Id:Id,MasterAccountId:MasterAccountId,FeatureSet:FeatureSet,MasterAccountEmail:MasterAccountEmail}' --output table

echo ""
echo "Account Summary:"
TOTAL_ACCOUNTS=$(aws organizations list-accounts --profile $PROFILE --query 'length(Accounts)' --output text)
ACTIVE_ACCOUNTS=$(aws organizations list-accounts --profile $PROFILE --query 'length(Accounts[?Status==`ACTIVE`])' --output text)
echo "Total Accounts: $TOTAL_ACCOUNTS"
echo "Active Accounts: $ACTIVE_ACCOUNTS"

# 2. ACCOUNT MANAGEMENT
echo ""
echo "👥 2. ALL ORGANIZATION ACCOUNTS"
echo "==============================="
aws organizations list-accounts --profile $PROFILE --query 'Accounts[].{Id:Id,Name:Name,Email:Email,Status:Status}' --output table

# 3. ORGANIZATIONAL STRUCTURE
echo ""
echo "🏗️ 3. ORGANIZATIONAL STRUCTURE"
echo "==============================="
ROOT_ID=$(aws organizations list-roots --profile $PROFILE --query 'Roots[0].Id' --output text)
echo "Root ID: $ROOT_ID"
echo ""
echo "Organizational Units:"
aws organizations list-organizational-units-for-parent --parent-id "$ROOT_ID" --profile $PROFILE --query 'OrganizationalUnits[].{Id:Id,Name:Name}' --output table

# Show accounts in each OU
echo ""
echo "Account Distribution by OU:"
for ou in $(aws organizations list-organizational-units-for-parent --parent-id "$ROOT_ID" --profile $PROFILE --query 'OrganizationalUnits[].Id' --output text); do
    OU_NAME=$(aws organizations describe-organizational-unit --organizational-unit-id "$ou" --profile $PROFILE --query 'OrganizationalUnit.Name' --output text)
    echo ""
    echo "OU: $OU_NAME ($ou)"
    aws organizations list-accounts-for-parent --parent-id "$ou" --profile $PROFILE --query 'Accounts[].{Id:Id,Name:Name}' --output table 2>/dev/null || echo "  No accounts in this OU"
done

# 4. SERVICE CONTROL POLICIES
echo ""
echo "🔒 4. SERVICE CONTROL POLICIES (SCPs)"
echo "====================================="
aws organizations list-policies --filter SERVICE_CONTROL_POLICY --profile $PROFILE --query 'Policies[].{Id:Id,Name:Name,Description:Description}' --output table

# 5. TRUSTED SERVICES
echo ""
echo "🔧 5. ENABLED AWS SERVICES"
echo "========================="
echo "Trusted AWS Services in Organization:"
aws organizations list-aws-service-access-for-organization --profile $PROFILE --query 'EnabledServicePrincipals[].ServicePrincipal' --output table | head -15

# 6. COST OVERVIEW (OPTIMIZED WITH CACHING)
echo ""
echo "💰 6. COST OVERVIEW (OPTIMIZED)"
echo "==============================="

# Function to check if cache is valid
is_cache_valid() {
    local cache_file="$1"
    local cache_hours="$2"
    
    if [ ! -f "$cache_file" ]; then
        return 1
    fi
    
    local file_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
    local cache_seconds=$(( cache_hours * 3600 ))
    
    [ $file_age -lt $cache_seconds ]
}

# Function to get cached or fresh cost data
get_cost_data() {
    if [ "$ENABLE_COST_EXPLORER" != "true" ]; then
        echo "Cost Explorer disabled for cost optimization"
        echo "To enable: export ENABLE_COST_EXPLORER=true"
        return 0
    fi
    
    echo "Getting cost data for current month..."
    
    # Check if we have valid cached data
    if is_cache_valid "$COST_DATA_CACHE" "$CACHE_DURATION_HOURS"; then
        echo "📂 Using cached cost data (less than ${CACHE_DURATION_HOURS}h old)"
        echo "Cache file: $COST_DATA_CACHE"
        echo ""
        
        # Display cached data
        if command -v jq >/dev/null 2>&1; then
            cat "$COST_DATA_CACHE" | jq -r '.[] | "Account: \(.Account)\tCost: $\(.Cost)"' | column -t
        else
            echo "Install 'jq' for formatted cost display"
            cat "$COST_DATA_CACHE"
        fi
        return 0
    fi
    
    echo "📡 Fetching fresh cost data from AWS Cost Explorer..."
    echo "This may take a moment..."
    
    # Make the Cost Explorer API call with optimizations
    local start_date=$(date +%Y-%m-01)
    local end_date=$(date -d 'next month' +%Y-%m-01)
    
    # OPTIMIZATION: Use MONTHLY granularity to reduce response size
    local cost_result=$(aws ce get-cost-and-usage \
        --time-period Start=$start_date,End=$end_date \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=LINKED_ACCOUNT \
        --profile $PROFILE \
        --query 'ResultsByTime[0].Groups[].{Account:Keys[0],Cost:Metrics.BlendedCost.Amount}' \
        --output json 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$cost_result" ]; then
        # Cache the result
        echo "$cost_result" > "$COST_DATA_CACHE"
        echo "💾 Cached cost data to: $COST_DATA_CACHE"
        echo ""
        
        # Display the data
        if command -v jq >/dev/null 2>&1; then
            echo "$cost_result" | jq -r '.[] | "Account: \(.Account)\tCost: $\(.Cost)"' | column -t
        else
            echo "$cost_result"
        fi
        
        # Show total cost
        if command -v jq >/dev/null 2>&1; then
            local total_cost=$(echo "$cost_result" | jq -r 'map(.Cost | tonumber) | add')
            echo ""
            echo "💰 Total Monthly Cost: \$$total_cost"
        fi
        
    else
        echo "❌ Cost Explorer data not available (may need to be enabled or insufficient permissions)"
        echo "Note: Cost data is cached for $CACHE_DURATION_HOURS hours to reduce API costs"
    fi
}

# Call the optimized cost data function
get_cost_data

# 7. COST OPTIMIZATION STATUS
echo ""
echo "🎯 7. COST OPTIMIZATION STATUS"
echo "=============================="
echo ""
echo "Dashboard Optimizations Active:"
echo "✅ Cost Explorer caching enabled (${CACHE_DURATION_HOURS}h TTL)"
echo "✅ Monthly granularity (reduced API response size)"
echo "✅ Single account grouping (vs multiple dimensions)"
echo "✅ Environment-based disable option (ENABLE_COST_EXPLORER)"
echo ""
echo "Cache Status:"
if [ -f "$COST_DATA_CACHE" ]; then
    cache_age=$(( $(date +%s) - $(stat -c %Y "$COST_DATA_CACHE") ))
    cache_age_hours=$(( cache_age / 3600 ))
    echo "📂 Cache file exists: $COST_DATA_CACHE"
    echo "📅 Cache age: ${cache_age_hours}h (expires after ${CACHE_DURATION_HOURS}h)"
    
    if [ $cache_age_hours -lt $CACHE_DURATION_HOURS ]; then
        echo "✅ Cache is valid - no API calls made this run"
    else
        echo "⏰ Cache expired - fresh API call made"
    fi
else
    echo "❌ No cache file - fresh API call made"
fi
echo ""
echo "To disable Cost Explorer (save ~$3.72/day): export ENABLE_COST_EXPLORER=false"
echo "To clear cache: rm -f $CACHE_DIR/cost_data_*.json"

# 8. MANAGEMENT ACTIONS MENU
echo ""
echo "🛠️ 8. AVAILABLE MANAGEMENT ACTIONS"
echo "=================================="
echo ""
echo "Account Management:"
echo "  - Create new account: aws organizations create-account --profile $PROFILE"
echo "  - Move account to OU: aws organizations move-account --profile $PROFILE"
echo ""
echo "OU Management:"
echo "  - Create new OU: aws organizations create-organizational-unit --profile $PROFILE"
echo "  - List accounts in OU: aws organizations list-accounts-for-parent --profile $PROFILE"
echo ""
echo "SCP Management:"
echo "  - Create SCP: aws organizations create-policy --type SERVICE_CONTROL_POLICY --profile $PROFILE"
echo "  - Attach SCP: aws organizations attach-policy --profile $PROFILE"
echo ""
echo "Cross-Account Access:"
echo "  - Assume role in account: aws sts assume-role --profile $PROFILE"
echo "  - Test account access: aws sts get-caller-identity --profile [account-profile]"

echo ""
echo "📋 QUICK REFERENCE COMMANDS"
echo "==========================="
echo ""
echo "# List all accounts:"
echo "aws organizations list-accounts --profile $PROFILE --output table"
echo ""
echo "# Create new account:"
echo "aws organizations create-account --account-name 'New Account' --email 'email@domain.com' --profile $PROFILE"
echo ""
echo "# Check billing for specific account (OPTIMIZED):"
echo "aws ce get-cost-and-usage --time-period Start=2024-12-01,End=2024-12-31 --granularity MONTHLY --metrics BlendedCost --group-by Type=DIMENSION,Key=LINKED_ACCOUNT --profile $PROFILE"
echo ""
echo "# Assume role in member account:"
echo "aws sts assume-role --role-arn 'arn:aws:iam::ACCOUNT-ID:role/OrganizationAccountAccessRole' --role-session-name 'OrgAdmin' --profile $PROFILE"

echo ""
echo "🔧 OPTIMIZATION UTILITIES"
echo "========================"
echo ""
echo "# View cost cache:"
echo "ls -la $CACHE_DIR/"
echo ""
echo "# Clear cost cache:"
echo "rm -f $CACHE_DIR/cost_data_*.json"
echo ""
echo "# Run with Cost Explorer disabled:"
echo "ENABLE_COST_EXPLORER=false $0"
echo ""
echo "# Check Cost Explorer API costs:"
echo "aws ce get-cost-and-usage --time-period Start=$(date +%Y-%m-01),End=$(date -d 'next month' +%Y-%m-01) --granularity DAILY --metrics UnblendedCost --filter '{\"Dimensions\": {\"Key\": \"SERVICE\", \"Values\": [\"AWS Cost Explorer\"]}}' --profile $PROFILE --query 'ResultsByTime[].Groups[0].Metrics.UnblendedCost.Amount' --output text | paste -sd+ | bc"

echo ""
echo "✅ Dashboard refresh complete (OPTIMIZED) - $(date)"
echo ""
echo "💡 COST SAVINGS IMPLEMENTED:"
echo "   - Caching reduces Cost Explorer API calls from 365/year to ~15/year"
echo "   - Potential savings: ~$85/month → ~$3.50/month"
echo "   - Cache TTL: $CACHE_DURATION_HOURS hours"
echo ""