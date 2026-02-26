#!/bin/bash
#
# AWS Resource Discovery Coverage Validation Script
# Validates that all AWS services, regions, and resources are properly extracted
#

set -euo pipefail

INVENTORY_FILE="${1:-/home/daclab-ai/DEV/AWS-DevOps/aws-inventory.json}"

log_info() {
    echo -e "\033[34m[INFO]\033[0m $*"
}

log_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $*"
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $*"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $*"
}

# Check if inventory file exists
if [[ ! -f "$INVENTORY_FILE" ]]; then
    log_error "Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

log_info "=========================================="
log_info "AWS Resource Discovery Coverage Validation"
log_info "=========================================="
log_info "Inventory file: $INVENTORY_FILE"

# Validate JSON structure
if ! jq empty "$INVENTORY_FILE" 2>/dev/null; then
    log_error "Invalid JSON in inventory file"
    exit 1
fi

log_success "JSON structure is valid"

# Check metadata
log_info "Validating metadata..."
METADATA=$(jq '.metadata' "$INVENTORY_FILE")
ORG_ID=$(echo "$METADATA" | jq -r '.organization_id // "N/A"')
ACCOUNTS_COUNT=$(echo "$METADATA" | jq '.accounts_scanned | length')
REGIONS=$(echo "$METADATA" | jq -r '.regions_scanned[]' | tr '\n' ',' | sed 's/,$//')
SCAN_DURATION=$(echo "$METADATA" | jq '.scan_duration_seconds')

log_info "Organization ID: $ORG_ID"
log_info "Accounts to scan: $ACCOUNTS_COUNT"
log_info "Regions scanned: $REGIONS"
log_info "Scan duration: ${SCAN_DURATION}s"

# Check accounts array
ACTUAL_ACCOUNTS=$(jq '.accounts | length' "$INVENTORY_FILE")
log_info "Accounts in inventory: $ACTUAL_ACCOUNTS"

if [[ "$ACTUAL_ACCOUNTS" -eq 0 ]]; then
    log_error "No accounts found in inventory - data extraction failed"
    exit 1
elif [[ "$ACTUAL_ACCOUNTS" -ne "$ACCOUNTS_COUNT" ]]; then
    log_warn "Mismatch: Expected $ACCOUNTS_COUNT accounts, found $ACTUAL_ACCOUNTS"
else
    log_success "Account count matches expected: $ACTUAL_ACCOUNTS"
fi

# Validate service coverage for each account/region
EXPECTED_SERVICES=(
    "compute.ec2_instances"
    "compute.ecs_clusters"
    "compute.ecs_services"
    "compute.lambda_functions"
    "storage.s3_buckets"
    "database.dynamodb_tables"
    "database.rds_instances"
    "networking.vpcs"
    "networking.load_balancers"
    "networking.api_gateways"
    "containers.ecr_repositories"
    "security.secrets"
    "security.kms_keys"
    "auth.cognito_user_pools"
    "monitoring.cloudwatch_log_groups"
    "monitoring.eventbridge_rules"
    "messaging.sns_topics"
    "messaging.sqs_queues"
    "frontend.amplify_apps"
)

GLOBAL_SERVICES=(
    "networking.cloudfront_distributions"
    "security.iam_roles"
    "dns.route53_zones"
)

log_info "Validating service coverage per account/region..."

MISSING_SERVICES=()
ACCOUNTS_WITH_DATA=0

for account_idx in $(seq 0 $((ACTUAL_ACCOUNTS - 1))); do
    ACCOUNT_ID=$(jq -r ".accounts[$account_idx].account_id" "$INVENTORY_FILE")
    ACCOUNT_NAME=$(jq -r ".accounts[$account_idx].account_name" "$INVENTORY_FILE")
    REGIONS_COUNT=$(jq ".accounts[$account_idx].regions | length" "$INVENTORY_FILE")
    
    log_info "Account $((account_idx + 1)): $ACCOUNT_NAME ($ACCOUNT_ID) - $REGIONS_COUNT regions"
    
    if [[ "$REGIONS_COUNT" -gt 0 ]]; then
        ACCOUNTS_WITH_DATA=$((ACCOUNTS_WITH_DATA + 1))
    fi
    
    # Check each region
    for region_idx in $(seq 0 $((REGIONS_COUNT - 1))); do
        REGION=$(jq -r ".accounts[$account_idx].regions[$region_idx].region" "$INVENTORY_FILE")
        
        # Check regional services
        if [[ "$REGION" != "global" ]]; then
            for service in "${EXPECTED_SERVICES[@]}"; do
                SERVICE_EXISTS=$(jq ".accounts[$account_idx].regions[$region_idx].services.$service != null" "$INVENTORY_FILE")
                if [[ "$SERVICE_EXISTS" != "true" ]]; then
                    MISSING_SERVICES+=("$ACCOUNT_ID/$REGION/$service")
                fi
            done
        else
            # Check global services
            for service in "${GLOBAL_SERVICES[@]}"; do
                SERVICE_EXISTS=$(jq ".accounts[$account_idx].regions[$region_idx].services.$service != null" "$INVENTORY_FILE")
                if [[ "$SERVICE_EXISTS" != "true" ]]; then
                    MISSING_SERVICES+=("$ACCOUNT_ID/global/$service")
                fi
            done
        fi
    done
done

# Count total resources
log_info "Counting resources..."

RESOURCE_COUNTS=()
for service in "${EXPECTED_SERVICES[@]}" "${GLOBAL_SERVICES[@]}"; do
    COUNT=$(jq "[.accounts[].regions[].services.$service // [] | length] | add // 0" "$INVENTORY_FILE")
    if [[ "$COUNT" -gt 0 ]]; then
        RESOURCE_COUNTS+=("$service: $COUNT")
    fi
done

# S3 bucket special validation (global but region-specific)
S3_BUCKETS_TOTAL=$(jq '[.accounts[].regions[] | select(.region != "global") | .services.storage.s3_buckets // [] | length] | add // 0' "$INVENTORY_FILE")
if [[ "$S3_BUCKETS_TOTAL" -gt 0 ]]; then
    log_info "S3 buckets found across all regions: $S3_BUCKETS_TOTAL"
fi

# Report findings
log_info "=========================================="
log_info "COVERAGE VALIDATION RESULTS"
log_info "=========================================="

if [[ ${#MISSING_SERVICES[@]} -eq 0 ]]; then
    log_success "✅ ALL SERVICES COVERED - No missing services detected"
else
    log_warn "⚠️  Missing services detected: ${#MISSING_SERVICES[@]} instances"
    for missing in "${MISSING_SERVICES[@]:0:10}"; do  # Show first 10
        log_warn "   - $missing"
    done
    if [[ ${#MISSING_SERVICES[@]} -gt 10 ]]; then
        log_warn "   ... and $((${#MISSING_SERVICES[@]} - 10)) more"
    fi
fi

log_info "Accounts with data: $ACCOUNTS_WITH_DATA/$ACTUAL_ACCOUNTS"

if [[ ${#RESOURCE_COUNTS[@]} -gt 0 ]]; then
    log_info "Resource counts by service:"
    for count in "${RESOURCE_COUNTS[@]}"; do
        log_info "   $count"
    done
else
    log_warn "⚠️  No resources found in any service"
fi

# Specific S3 validation
log_info "Validating S3 bucket coverage..."
S3_REGIONS=$(jq -r '[.accounts[].regions[] | select(.region != "global") | select(.services.storage.s3_buckets | length > 0) | .region] | unique | join(", ")' "$INVENTORY_FILE")
if [[ -n "$S3_REGIONS" && "$S3_REGIONS" != "" ]]; then
    log_success "✅ S3 buckets found in regions: $S3_REGIONS"
else
    log_warn "⚠️  No S3 buckets found in any region"
fi

# Validate organization coverage
if [[ "$ORG_ID" != "N/A" ]]; then
    log_success "✅ Organization-wide scan completed (Org ID: $ORG_ID)"
else
    log_warn "⚠️  Single account scan (not organization-wide)"
fi

# Final assessment
COVERAGE_SCORE=$((100 - (${#MISSING_SERVICES[@]} * 100 / (${#EXPECTED_SERVICES[@]} + ${#GLOBAL_SERVICES[@]}) / ACTUAL_ACCOUNTS)))
if [[ "$COVERAGE_SCORE" -lt 0 ]]; then
    COVERAGE_SCORE=0
fi

log_info "=========================================="
if [[ "$COVERAGE_SCORE" -ge 90 ]]; then
    log_success "🎉 COMPREHENSIVE COVERAGE ACHIEVED: ${COVERAGE_SCORE}%"
elif [[ "$COVERAGE_SCORE" -ge 70 ]]; then
    log_warn "⚠️  GOOD COVERAGE: ${COVERAGE_SCORE}% (some services missing)"
else
    log_error "❌ INCOMPLETE COVERAGE: ${COVERAGE_SCORE}% (significant gaps detected)"
fi

log_info "Validation completed."
echo

exit 0