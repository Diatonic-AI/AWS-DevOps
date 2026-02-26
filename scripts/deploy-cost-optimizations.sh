#!/bin/bash

# Deploy Cost Explorer Optimizations
# This script deploys all the cost reduction measures and validates they work

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$HOME/cost-optimization-deployment-$TIMESTAMP.log"

# Configuration
ENVIRONMENT=${ENVIRONMENT:-"dev"}
AWS_PROFILE=${AWS_PROFILE:-"dfortini-local"}
DRY_RUN=${DRY_RUN:-"true"}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [ACTIONS]

Actions:
    deploy         Deploy all cost optimization infrastructure and code
    test           Test the optimized functions
    rollback       Rollback to original functions  
    status         Check current optimization status
    estimate       Show cost savings estimates
    all            Deploy, test, and show status

Options:
    --dry-run      Show what would be done (default)
    --execute      Actually perform the actions
    --env ENV      Environment (dev, staging, prod) [default: dev]
    --profile PROF AWS CLI profile [default: dfortini-local]
    --help         Show this help

Examples:
    # See what would be deployed
    $0 deploy

    # Actually deploy optimizations  
    $0 deploy --execute --env dev

    # Test optimized functions
    $0 test --execute

    # Check current status
    $0 status

Environment Variables:
    DRY_RUN=false        Execute changes
    ENVIRONMENT=prod     Target environment
    AWS_PROFILE=profile  AWS profile to use
EOF
}

# Parse arguments
ACTIONS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        deploy|test|rollback|status|estimate|all)
            ACTIONS+=("$1")
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --execute)
            DRY_RUN="false"
            shift
            ;;
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [ ${#ACTIONS[@]} -eq 0 ]; then
    ACTIONS=("status")
fi

log "Starting Cost Explorer optimization deployment..."
log "Environment: $ENVIRONMENT"
log "AWS Profile: $AWS_PROFILE"  
log "Dry Run: $DRY_RUN"
log "Log file: $LOG_FILE"
log ""

# Function to deploy cache infrastructure
deploy_cache_infrastructure() {
    log "Deploying DynamoDB cache tables..."
    
    local tf_dir="$SCRIPT_DIR/infrastructure/terraform/modules/cost-explorer-cache"
    
    if [ ! -d "$tf_dir" ]; then
        error "Terraform module directory not found: $tf_dir"
        return 1
    fi
    
    cd "$tf_dir"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would run: terraform init && terraform plan"
        log "[DRY RUN] Would create cache tables for environment: $ENVIRONMENT"
        return 0
    fi
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    log "Planning cache infrastructure..."
    terraform plan \
        -var="environment=$ENVIRONMENT" \
        -var="create_dashboard=true" \
        -var="enable_point_in_time_recovery=false" \
        -out="cache-plan.tfplan"
    
    # Apply if not dry run
    log "Applying cache infrastructure..."
    terraform apply "cache-plan.tfplan"
    
    success "Cache infrastructure deployed successfully"
    
    # Get outputs
    local partner_cache=$(terraform output -raw partner_dashboard_cache_table_name)
    local client_cache=$(terraform output -raw client_billing_cache_table_name)
    
    log "Created cache tables:"
    log "  Partner Dashboard: $partner_cache"
    log "  Client Billing: $client_cache"
}

# Function to deploy optimized Lambda functions
deploy_optimized_lambdas() {
    log "Deploying optimized Lambda functions..."
    
    local partner_function="stripe-cost-monitor-prod"  # Replace with actual function name
    local client_function="client-billing-costs"       # Replace with actual function name
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would update Lambda functions with optimized code"
        log "[DRY RUN] Would set environment variables for cache tables"
        return 0
    fi
    
    # Update partner dashboard Lambda
    if aws lambda get-function --function-name "$partner_function" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
        log "Updating partner dashboard Lambda function..."
        
        # Package the optimized code
        local temp_dir=$(mktemp -d)
        cp "$SCRIPT_DIR/infrastructure/terraform/modules/partner-dashboard/lambda/index-optimized.js" "$temp_dir/index.js"
        cd "$temp_dir"
        zip -r function.zip .
        
        # Update function code
        aws lambda update-function-code \
            --function-name "$partner_function" \
            --zip-file fileb://function.zip \
            --profile "$AWS_PROFILE"
        
        # Update environment variables
        local current_env=$(aws lambda get-function-configuration \
            --function-name "$partner_function" \
            --profile "$AWS_PROFILE" \
            --query 'Environment.Variables' \
            --output json)
        
        local updated_env=$(echo "$current_env" | jq --arg cache "${ENVIRONMENT}-partner-dashboard-cost-cache" '. + {"COST_CACHE_TABLE": $cache}')
        
        aws lambda update-function-configuration \
            --function-name "$partner_function" \
            --environment "Variables=$updated_env" \
            --profile "$AWS_PROFILE"
        
        success "Updated partner dashboard Lambda function"
        
        # Cleanup
        rm -rf "$temp_dir"
    else
        warn "Partner dashboard Lambda function not found: $partner_function"
    fi
    
    # Update client billing Lambda
    if aws lambda get-function --function-name "$client_function" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
        log "Updating client billing Lambda function..."
        
        # Package the optimized code
        local temp_dir=$(mktemp -d)
        cp "$SCRIPT_DIR/lambda/client-billing-costs/index-optimized.js" "$temp_dir/index.js"
        cd "$temp_dir"
        zip -r function.zip .
        
        # Update function code
        aws lambda update-function-code \
            --function-name "$client_function" \
            --zip-file fileb://function.zip \
            --profile "$AWS_PROFILE"
        
        # Update environment variables
        local current_env=$(aws lambda get-function-configuration \
            --function-name "$client_function" \
            --profile "$AWS_PROFILE" \
            --query 'Environment.Variables' \
            --output json)
        
        local updated_env=$(echo "$current_env" | jq \
            --arg cache "${ENVIRONMENT}-client-billing-cost-cache" \
            --arg forecast "false" \
            '. + {"CACHE_TABLE": $cache, "ENABLE_FORECASTING": $forecast}')
        
        aws lambda update-function-configuration \
            --function-name "$client_function" \
            --environment "Variables=$updated_env" \
            --profile "$AWS_PROFILE"
        
        success "Updated client billing Lambda function"
        
        # Cleanup
        rm -rf "$temp_dir"
    else
        warn "Client billing Lambda function not found: $client_function"
    fi
}

# Function to test optimized functions
test_optimizations() {
    log "Testing optimized Cost Explorer functions..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would test Lambda functions and verify caching works"
        return 0
    fi
    
    # Test partner dashboard function
    log "Testing partner dashboard function..."
    local partner_result=$(aws lambda invoke \
        --function-name "stripe-cost-monitor-prod" \
        --payload '{"requestContext":{"http":{"method":"GET","path":"/costs"}}}' \
        --profile "$AWS_PROFILE" \
        /tmp/partner_test_output.json 2>&1 || echo "Function not found")
    
    if [ -f "/tmp/partner_test_output.json" ]; then
        local cached=$(cat /tmp/partner_test_output.json | jq -r '.cached // false')
        log "Partner function test result: cached=$cached"
    else
        warn "Partner function test failed or function not found"
    fi
    
    # Test client billing function
    log "Testing client billing function..."
    local client_result=$(aws lambda invoke \
        --function-name "client-billing-costs" \
        --payload '{"clientOrganization":"test-client","period":"current-month"}' \
        --profile "$AWS_PROFILE" \
        /tmp/client_test_output.json 2>&1 || echo "Function not found")
    
    if [ -f "/tmp/client_test_output.json" ]; then
        local cached=$(cat /tmp/client_test_output.json | jq -r '.cached // false')
        log "Client function test result: cached=$cached"
    else
        warn "Client function test failed or function not found"
    fi
    
    # Cleanup
    rm -f /tmp/partner_test_output.json /tmp/client_test_output.json
}

# Function to check optimization status
check_status() {
    log "Checking Cost Explorer optimization status..."
    
    # Check if cache tables exist
    log "Checking DynamoDB cache tables..."
    for table in "${ENVIRONMENT}-partner-dashboard-cost-cache" "${ENVIRONMENT}-client-billing-cost-cache"; do
        if aws dynamodb describe-table --table-name "$table" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
            success "✅ Cache table exists: $table"
            
            # Check item count
            local item_count=$(aws dynamodb describe-table \
                --table-name "$table" \
                --profile "$AWS_PROFILE" \
                --query 'Table.ItemCount' \
                --output text)
            log "   Items in cache: $item_count"
        else
            warn "❌ Cache table missing: $table"
        fi
    done
    
    # Check Lambda function configurations
    log "Checking Lambda function optimizations..."
    for func in "stripe-cost-monitor-prod" "client-billing-costs"; do
        if aws lambda get-function --function-name "$func" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
            local env_vars=$(aws lambda get-function-configuration \
                --function-name "$func" \
                --profile "$AWS_PROFILE" \
                --query 'Environment.Variables' \
                --output json)
            
            local cache_table=$(echo "$env_vars" | jq -r '.CACHE_TABLE // .COST_CACHE_TABLE // "not_set"')
            local disable_flag=$(echo "$env_vars" | jq -r '.DISABLE_COST_EXPLORER // "not_set"')
            local enable_forecast=$(echo "$env_vars" | jq -r '.ENABLE_FORECASTING // "not_set"')
            
            log "📋 Function: $func"
            log "   Cache table: $cache_table"
            log "   Cost Explorer disabled: $disable_flag"
            log "   Forecasting enabled: $enable_forecast"
        else
            warn "❌ Function not found: $func"
        fi
    done
    
    # Check Cost Explorer usage
    log "Checking current Cost Explorer usage..."
    local current_month_start=$(date +%Y-%m-01)
    local today=$(date +%Y-%m-%d)
    
    local monthly_cost=$(aws ce get-cost-and-usage \
        --time-period Start=$current_month_start,End=$today \
        --granularity MONTHLY \
        --metrics UnblendedCost \
        --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["AWS Cost Explorer"]}}' \
        --profile "$AWS_PROFILE" \
        --query 'ResultsByTime[0].Groups[0].Metrics.UnblendedCost.Amount' \
        --output text 2>/dev/null || echo "Unable to fetch")
    
    log "💰 Current month Cost Explorer usage: \$$monthly_cost"
}

# Function to show cost estimates
show_cost_estimates() {
    log "Cost Explorer Optimization Estimates"
    log "==================================="
    log ""
    log "📊 BEFORE OPTIMIZATION:"
    log "   Daily Cost Explorer API calls: ~372"
    log "   Daily cost: \$3.72"
    log "   Monthly cost: \$112.32"
    log "   Annual cost: \$1,357.80"
    log ""
    log "📈 AFTER OPTIMIZATION:"
    log "   Daily Cost Explorer API calls: ~15 (cache misses)"
    log "   Daily cost: \$0.15 + DynamoDB"
    log "   Monthly cost: \$4.50 + ~\$2.00 DynamoDB"
    log "   Annual cost: \$54.00 + DynamoDB"
    log ""
    log "💰 ESTIMATED SAVINGS:"
    log "   Monthly savings: ~\$105"
    log "   Annual savings: ~\$1,260"
    log "   ROI: 95%+ cost reduction"
    log ""
    log "🎯 OPTIMIZATIONS IMPLEMENTED:"
    log "   ✅ DynamoDB caching (24-hour TTL)"
    log "   ✅ Reduced granularity (MONTHLY for historical)"
    log "   ✅ Limited date ranges (7 days vs 30 days)"
    log "   ✅ Batch processing for multiple clients"
    log "   ✅ Optional forecasting (disabled by default)"
    log "   ✅ Script-based caching for org dashboard"
}

# Main execution
for action in "${ACTIONS[@]}"; do
    case "$action" in
        "deploy")
            deploy_cache_infrastructure
            deploy_optimized_lambdas
            ;;
        "test")
            test_optimizations
            ;;
        "status")
            check_status
            ;;
        "estimate")
            show_cost_estimates
            ;;
        "all")
            deploy_cache_infrastructure
            deploy_optimized_lambdas  
            test_optimizations
            check_status
            show_cost_estimates
            ;;
        "rollback")
            warn "Rollback functionality not implemented in this script"
            warn "To rollback, manually restore original Lambda code"
            ;;
        *)
            error "Unknown action: $action"
            exit 1
            ;;
    esac
    log ""
done

success "Cost Explorer optimization deployment completed!"
log "Log file saved to: $LOG_FILE"

if [ "$DRY_RUN" = "true" ]; then
    warn "This was a DRY RUN. Use --execute to actually deploy changes."
fi