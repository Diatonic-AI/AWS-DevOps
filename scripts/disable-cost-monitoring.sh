#!/bin/bash

# Temporarily Disable Cost-Heavy Monitoring to Reduce Cost Explorer API Usage
# This script can disable/enable expensive monitoring without permanent changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.cost-monitoring-backups"

# Configuration
PROFILE="dfortini-local"
DRY_RUN=${DRY_RUN:-"true"} # Default to dry run for safety

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    disable     Temporarily disable cost-heavy monitoring
    enable      Re-enable previously disabled monitoring  
    status      Check status of cost monitoring services
    backup      Backup current monitoring configuration
    restore     Restore monitoring from backup

Options:
    --dry-run   Show what would be done without making changes (default)
    --execute   Actually execute the changes
    --profile   AWS CLI profile to use (default: dfortini-local)
    --help      Show this help message

Examples:
    # See what would be disabled (dry run)
    $0 disable

    # Actually disable cost monitoring
    $0 disable --execute

    # Check current status
    $0 status

    # Re-enable monitoring
    $0 enable --execute

Environment Variables:
    DRY_RUN=false     Execute changes instead of dry run
    AWS_PROFILE       AWS CLI profile to use
EOF
}

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        disable|enable|status|backup|restore)
            COMMAND="$1"
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
        --profile)
            PROFILE="$2"
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

if [ -z "$COMMAND" ]; then
    error "Command required"
    usage
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to backup EventBridge rule
backup_eventbridge_rule() {
    local rule_name="$1"
    local backup_file="$BACKUP_DIR/${rule_name}_${TIMESTAMP}.json"
    
    log "Backing up EventBridge rule: $rule_name"
    
    if aws events describe-rule --name "$rule_name" --profile "$PROFILE" > "$backup_file" 2>/dev/null; then
        success "Backed up rule to: $backup_file"
        
        # Also backup targets
        local targets_file="$BACKUP_DIR/${rule_name}_targets_${TIMESTAMP}.json"
        aws events list-targets-by-rule --rule "$rule_name" --profile "$PROFILE" > "$targets_file" 2>/dev/null
        success "Backed up targets to: $targets_file"
    else
        warn "Rule $rule_name not found or backup failed"
    fi
}

# Function to disable EventBridge rule
disable_eventbridge_rule() {
    local rule_name="$1"
    
    log "Disabling EventBridge rule: $rule_name"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "  [DRY RUN] Would disable: aws events disable-rule --name $rule_name --profile $PROFILE"
        return 0
    fi
    
    if aws events disable-rule --name "$rule_name" --profile "$PROFILE" 2>/dev/null; then
        success "Disabled rule: $rule_name"
    else
        warn "Failed to disable rule: $rule_name (may not exist)"
    fi
}

# Function to enable EventBridge rule
enable_eventbridge_rule() {
    local rule_name="$1"
    
    log "Enabling EventBridge rule: $rule_name"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "  [DRY RUN] Would enable: aws events enable-rule --name $rule_name --profile $PROFILE"
        return 0
    fi
    
    if aws events enable-rule --name "$rule_name" --profile "$PROFILE" 2>/dev/null; then
        success "Enabled rule: $rule_name"
    else
        warn "Failed to enable rule: $rule_name"
    fi
}

# Function to set Lambda environment variable to disable Cost Explorer
disable_lambda_cost_explorer() {
    local function_name="$1"
    local env_var_name="$2"
    
    log "Disabling Cost Explorer for Lambda: $function_name"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "  [DRY RUN] Would set environment variable $env_var_name=false for $function_name"
        return 0
    fi
    
    # Get current environment variables
    local current_env=$(aws lambda get-function-configuration --function-name "$function_name" --profile "$PROFILE" --query 'Environment.Variables' --output json 2>/dev/null || echo '{}')
    
    # Add/update the disable flag
    local updated_env=$(echo "$current_env" | jq --arg key "$env_var_name" --arg value "false" '. + {($key): $value}')
    
    if aws lambda update-function-configuration \
        --function-name "$function_name" \
        --environment "Variables=$updated_env" \
        --profile "$PROFILE" >/dev/null 2>&1; then
        success "Disabled Cost Explorer for: $function_name"
    else
        warn "Failed to update Lambda: $function_name (may not exist)"
    fi
}

# Function to enable Lambda Cost Explorer
enable_lambda_cost_explorer() {
    local function_name="$1"
    local env_var_name="$2"
    
    log "Enabling Cost Explorer for Lambda: $function_name"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "  [DRY RUN] Would set environment variable $env_var_name=true for $function_name"
        return 0
    fi
    
    # Get current environment variables
    local current_env=$(aws lambda get-function-configuration --function-name "$function_name" --profile "$PROFILE" --query 'Environment.Variables' --output json 2>/dev/null || echo '{}')
    
    # Add/update the enable flag
    local updated_env=$(echo "$current_env" | jq --arg key "$env_var_name" --arg value "true" '. + {($key): $value}')
    
    if aws lambda update-function-configuration \
        --function-name "$function_name" \
        --environment "Variables=$updated_env" \
        --profile "$PROFILE" >/dev/null 2>&1; then
        success "Enabled Cost Explorer for: $function_name"
    else
        warn "Failed to update Lambda: $function_name"
    fi
}

# Function to check status of monitoring services
check_status() {
    log "Checking status of cost monitoring services..."
    echo ""
    
    # Check EventBridge rules
    echo "📅 EventBridge Rules:"
    local rules=("stripe-daily-cost-check-prod")
    for rule in "${rules[@]}"; do
        local status=$(aws events describe-rule --name "$rule" --profile "$PROFILE" --query 'State' --output text 2>/dev/null || echo "NOT_FOUND")
        case "$status" in
            "ENABLED")
                echo "  ✅ $rule: ENABLED (will make Cost Explorer API calls)"
                ;;
            "DISABLED")
                echo "  🚫 $rule: DISABLED (Cost Explorer API calls stopped)"
                ;;
            "NOT_FOUND")
                echo "  ❌ $rule: NOT FOUND"
                ;;
        esac
    done
    
    echo ""
    echo "🔧 Lambda Functions:"
    local functions=("stripe-cost-monitor-prod" "client-billing-costs")
    for func in "${functions[@]}"; do
        local env_vars=$(aws lambda get-function-configuration --function-name "$func" --profile "$PROFILE" --query 'Environment.Variables' --output json 2>/dev/null || echo '{}')
        if [ "$env_vars" != "{}" ]; then
            local disable_flag=$(echo "$env_vars" | jq -r '.DISABLE_COST_EXPLORER // "not_set"')
            local enable_forecast=$(echo "$env_vars" | jq -r '.ENABLE_FORECASTING // "not_set"')
            
            echo "  📋 $func:"
            case "$disable_flag" in
                "true")
                    echo "    🚫 Cost Explorer: DISABLED"
                    ;;
                "false"|"not_set")
                    echo "    ✅ Cost Explorer: ENABLED (making API calls)"
                    ;;
            esac
            
            case "$enable_forecast" in
                "true")
                    echo "    📈 Forecasting: ENABLED (expensive API calls)"
                    ;;
                "false"|"not_set")
                    echo "    📈 Forecasting: DISABLED/DEFAULT"
                    ;;
            esac
        else
            echo "  ❌ $func: NOT FOUND or no environment variables"
        fi
    done
    
    echo ""
    echo "💰 Current Cost Explorer Usage:"
    local current_month_start=$(date +%Y-%m-01)
    local tomorrow=$(date -d 'tomorrow' +%Y-%m-%d)
    
    local daily_costs=$(aws ce get-cost-and-usage \
        --time-period Start=$current_month_start,End=$tomorrow \
        --granularity DAILY \
        --metrics UnblendedCost \
        --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["AWS Cost Explorer"]}}' \
        --profile "$PROFILE" \
        --query 'ResultsByTime[].Groups[0].Metrics.UnblendedCost.Amount' \
        --output text 2>/dev/null | grep -v "None" | tail -5 || echo "Unable to fetch")
    
    if [ "$daily_costs" != "Unable to fetch" ]; then
        echo "  Last 5 days of Cost Explorer charges:"
        echo "$daily_costs" | while read -r cost; do
            echo "    \$$cost"
        done
    else
        echo "  Unable to fetch current Cost Explorer usage"
    fi
}

# Main command execution
case "$COMMAND" in
    "status")
        check_status
        ;;
    
    "disable")
        log "Disabling cost-heavy monitoring services..."
        
        if [ "$DRY_RUN" = "true" ]; then
            warn "DRY RUN MODE - No actual changes will be made"
            warn "Use --execute to actually disable monitoring"
        else
            warn "EXECUTE MODE - Changes will be made!"
            log "Creating backups before making changes..."
        fi
        
        echo ""
        
        # Backup before disabling
        if [ "$DRY_RUN" = "false" ]; then
            backup_eventbridge_rule "stripe-daily-cost-check-prod"
        fi
        
        # Disable EventBridge rules
        disable_eventbridge_rule "stripe-daily-cost-check-prod"
        
        # Disable Cost Explorer in Lambda functions
        disable_lambda_cost_explorer "stripe-cost-monitor-prod" "DISABLE_COST_EXPLORER"
        disable_lambda_cost_explorer "client-billing-costs" "ENABLE_FORECASTING"
        
        echo ""
        success "Cost monitoring disable operation completed"
        
        if [ "$DRY_RUN" = "false" ]; then
            log "Estimated daily savings: \$3.72/day"
            log "Estimated monthly savings: \$112/month"
            log "Backups stored in: $BACKUP_DIR"
        fi
        ;;
    
    "enable")
        log "Re-enabling cost monitoring services..."
        
        if [ "$DRY_RUN" = "true" ]; then
            warn "DRY RUN MODE - No actual changes will be made"
            warn "Use --execute to actually enable monitoring"
        fi
        
        echo ""
        
        # Enable EventBridge rules
        enable_eventbridge_rule "stripe-daily-cost-check-prod"
        
        # Enable Cost Explorer in Lambda functions
        enable_lambda_cost_explorer "stripe-cost-monitor-prod" "DISABLE_COST_EXPLORER"
        enable_lambda_cost_explorer "client-billing-costs" "ENABLE_FORECASTING"
        
        echo ""
        success "Cost monitoring enable operation completed"
        
        if [ "$DRY_RUN" = "false" ]; then
            warn "Cost Explorer API usage will resume"
            log "Monitor costs with: aws ce get-cost-and-usage (see usage examples in script)"
        fi
        ;;
    
    "backup")
        log "Creating backup of monitoring configuration..."
        backup_eventbridge_rule "stripe-daily-cost-check-prod"
        success "Backup completed to: $BACKUP_DIR"
        ;;
    
    "restore")
        log "Restore functionality would be implemented here"
        warn "For now, use 'enable' command to restore basic functionality"
        ;;
    
    *)
        error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac

log "Operation completed."