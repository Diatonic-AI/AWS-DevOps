#!/bin/bash
#
# Terraform State Audit Script
# Compares AWS inventory against Terraform state to identify unmanaged resources
# Generates import commands for resources not managed by Terraform
#
# Usage:
#   ./terraform-audit.sh [options]
#
# Options:
#   --inventory FILE         AWS inventory JSON file (default: ./aws-inventory.json)
#   --output FILE           Output audit report file (default: ./terraform-audit-report.json)
#   --workspace PATH        Specific Terraform workspace to audit (default: all workspaces)
#   --generate-imports      Generate terraform import script file
#   --verbose               Enable verbose output
#   --help                  Display this help message
#
# Example:
#   ./terraform-audit.sh --inventory aws-inventory.json --generate-imports
#

set -euo pipefail

# Script metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
AWS_INVENTORY="${PROJECT_ROOT}/aws-inventory.json"
OUTPUT_FILE="${PROJECT_ROOT}/terraform-audit-report.json"
SPECIFIC_WORKSPACE=""
GENERATE_IMPORTS=false
VERBOSE=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $*" >&2
    fi
}

# Help message
show_help() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# //g' | sed 's/^#//g'
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --inventory)
                AWS_INVENTORY="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --workspace)
                SPECIFIC_WORKSPACE="$2"
                shift 2
                ;;
            --generate-imports)
                GENERATE_IMPORTS=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it first: sudo apt install jq"
        exit 1
    fi

    if [[ ! -f "$AWS_INVENTORY" ]]; then
        log_error "AWS inventory file not found: $AWS_INVENTORY"
        log_info "Run aws-resource-discovery.sh first to generate the inventory"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Find all Terraform state files
find_terraform_workspaces() {
    log_info "Discovering Terraform workspaces..."

    if [[ -n "$SPECIFIC_WORKSPACE" ]]; then
        if [[ -f "$SPECIFIC_WORKSPACE/terraform.tfstate" ]]; then
            echo "$SPECIFIC_WORKSPACE"
        else
            log_error "No terraform.tfstate found in: $SPECIFIC_WORKSPACE"
            exit 1
        fi
    else
        # Find all terraform.tfstate files, excluding .terraform directories
        find "$PROJECT_ROOT" -name "terraform.tfstate" \
            -not -path "*/.terraform/*" \
            -not -path "*/terraform.tfstate.d/*" \
            -type f \
            -exec dirname {} \; | sort -u
    fi
}

# Parse a single Terraform state file
parse_terraform_state() {
    local workspace_path=$1
    local state_file="${workspace_path}/terraform.tfstate"

    log_debug "Parsing Terraform state: $state_file"

    if [[ ! -f "$state_file" ]]; then
        echo "{}"
        return
    fi

    # Extract managed resources from state
    jq '{
        workspace_path: $workspace_path,
        version: .version,
        terraform_version: .terraform_version,
        resources: [
            .resources[]? |
            select(.mode == "managed") |
            {
                type: .type,
                name: .name,
                provider: .provider,
                mode: .mode,
                instances: [
                    .instances[]? |
                    {
                        attributes: .attributes,
                        id: (.attributes.id // .attributes.arn // "unknown")
                    }
                ]
            }
        ]
    }' --arg workspace_path "$workspace_path" "$state_file" 2>/dev/null || echo "{}"
}

# Map AWS service resources to Terraform resource types
get_terraform_resource_type() {
    local aws_service=$1
    local resource_type=$2

    # Map AWS inventory resource types to Terraform resource types
    case "${aws_service}:${resource_type}" in
        "compute:lambda_functions") echo "aws_lambda_function" ;;
        "compute:ec2_instances") echo "aws_instance" ;;
        "compute:ecs_clusters") echo "aws_ecs_cluster" ;;
        "compute:ecs_services") echo "aws_ecs_service" ;;
        "storage:s3_buckets") echo "aws_s3_bucket" ;;
        "storage:ebs_volumes") echo "aws_ebs_volume" ;;
        "storage:efs_filesystems") echo "aws_efs_file_system" ;;
        "database:dynamodb_tables") echo "aws_dynamodb_table" ;;
        "database:rds_instances") echo "aws_db_instance" ;;
        "database:rds_clusters") echo "aws_rds_cluster" ;;
        "networking:vpcs") echo "aws_vpc" ;;
        "networking:subnets") echo "aws_subnet" ;;
        "networking:security_groups") echo "aws_security_group" ;;
        "networking:load_balancers") echo "aws_lb" ;;
        "networking:api_gateways") echo "aws_api_gateway_rest_api" ;;
        "networking:cloudfront_distributions") echo "aws_cloudfront_distribution" ;;
        "containers:ecr_repositories") echo "aws_ecr_repository" ;;
        "security:iam_roles") echo "aws_iam_role" ;;
        "security:secrets") echo "aws_secretsmanager_secret" ;;
        "security:kms_keys") echo "aws_kms_key" ;;
        "dns:route53_zones") echo "aws_route53_zone" ;;
        "dns:route53_records") echo "aws_route53_record" ;;
        "auth:cognito_user_pools") echo "aws_cognito_user_pool" ;;
        "monitoring:cloudwatch_alarms") echo "aws_cloudwatch_metric_alarm" ;;
        "monitoring:cloudwatch_log_groups") echo "aws_cloudwatch_log_group" ;;
        "monitoring:eventbridge_rules") echo "aws_cloudwatch_event_rule" ;;
        "messaging:sns_topics") echo "aws_sns_topic" ;;
        "messaging:sqs_queues") echo "aws_sqs_queue" ;;
        "frontend:amplify_apps") echo "aws_amplify_app" ;;
        *) echo "unknown" ;;
    esac
}

# Get resource identifier for import
get_resource_identifier() {
    local resource_type=$1
    local resource_data=$2

    # Extract the appropriate identifier based on resource type
    case "$resource_type" in
        "aws_lambda_function")
            echo "$resource_data" | jq -r '.function_name // .arn'
            ;;
        "aws_instance")
            echo "$resource_data" | jq -r '.instance_id'
            ;;
        "aws_s3_bucket")
            echo "$resource_data" | jq -r '.bucket_name'
            ;;
        "aws_dynamodb_table")
            echo "$resource_data" | jq -r '.table_name'
            ;;
        "aws_ecs_cluster")
            echo "$resource_data" | jq -r '.arn // .cluster_name'
            ;;
        "aws_ecs_service")
            echo "$resource_data" | jq -r '.arn // .service_name'
            ;;
        "aws_vpc")
            echo "$resource_data" | jq -r '.vpc_id'
            ;;
        "aws_lb")
            echo "$resource_data" | jq -r '.arn'
            ;;
        "aws_api_gateway_rest_api")
            echo "$resource_data" | jq -r '.api_id'
            ;;
        "aws_ecr_repository")
            echo "$resource_data" | jq -r '.repository_name'
            ;;
        "aws_iam_role")
            echo "$resource_data" | jq -r '.role_name'
            ;;
        "aws_secretsmanager_secret")
            echo "$resource_data" | jq -r '.secret_name // .arn'
            ;;
        "aws_kms_key")
            echo "$resource_data" | jq -r '.key_id'
            ;;
        "aws_route53_zone")
            echo "$resource_data" | jq -r '.zone_id'
            ;;
        "aws_cognito_user_pool")
            echo "$resource_data" | jq -r '.pool_id'
            ;;
        "aws_cloudwatch_log_group")
            echo "$resource_data" | jq -r '.log_group_name'
            ;;
        "aws_cloudwatch_event_rule")
            echo "$resource_data" | jq -r '.rule_name'
            ;;
        "aws_sns_topic")
            echo "$resource_data" | jq -r '.topic_arn'
            ;;
        "aws_sqs_queue")
            echo "$resource_data" | jq -r '.queue_url'
            ;;
        "aws_amplify_app")
            echo "$resource_data" | jq -r '.app_id'
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Generate suggested Terraform resource name
generate_terraform_name() {
    local resource_identifier=$1

    # Convert identifier to valid Terraform name
    # Remove special characters, convert to lowercase, replace spaces/dots with underscores
    echo "$resource_identifier" | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9_-]/_/g' | \
        sed 's/__*/_/g' | \
        sed 's/^_//;s/_$//'
}

# Determine resource priority for import
get_import_priority() {
    local resource_type=$1

    # High priority: Core infrastructure
    case "$resource_type" in
        aws_vpc|aws_subnet|aws_route_table|aws_internet_gateway|aws_nat_gateway)
            echo "high" ;;
        aws_iam_role|aws_iam_policy|aws_kms_key)
            echo "high" ;;
        aws_dynamodb_table|aws_db_instance|aws_rds_cluster)
            echo "high" ;;

        # Medium priority: Application resources
        aws_lambda_function|aws_ecs_cluster|aws_ecs_service)
            echo "medium" ;;
        aws_s3_bucket|aws_ecr_repository)
            echo "medium" ;;
        aws_lb|aws_api_gateway_rest_api)
            echo "medium" ;;

        # Low priority: Monitoring, logs, etc.
        aws_cloudwatch_*|aws_sns_topic|aws_sqs_queue)
            echo "low" ;;

        *)
            echo "medium" ;;
    esac
}

# Compare AWS inventory against Terraform state
compare_resources() {
    local tf_state_json=$1
    local aws_inventory=$2

    log_info "Comparing AWS resources against Terraform state..."

    # Create temp file for unmanaged resources
    local unmanaged_file="/tmp/terraform_audit_unmanaged_$$.json"
    echo '{"by_service": {}, "total_count": 0}' > "$unmanaged_file"

    # Extract all managed resource identifiers from Terraform
    local managed_ids
    managed_ids=$(echo "$tf_state_json" | jq -r '
        [.workspaces[].resources[].instances[].id] |
        unique |
        .[]
    ' | sort -u)

    log_debug "Found $(echo "$managed_ids" | wc -l) managed resource IDs in Terraform"

    # Iterate through AWS inventory and check if resources are managed
    local total_unmanaged=0
    local services=("compute" "storage" "database" "networking" "containers" "security" "dns" "auth" "monitoring" "messaging")

    for service in "${services[@]}"; do
        log_debug "Checking service: $service"

        # Get resource types for this service
        local resource_types
        resource_types=$(jq -r --arg service "$service" '
            .accounts[0].regions[0].services[$service] |
            keys[]
        ' "$aws_inventory" 2>/dev/null || echo "")

        [[ -z "$resource_types" ]] && continue

        while IFS= read -r resource_type; do
            [[ -z "$resource_type" ]] && continue

            local tf_resource_type
            tf_resource_type=$(get_terraform_resource_type "$service" "$resource_type")

            [[ "$tf_resource_type" == "unknown" ]] && continue

            # Get resources of this type from AWS inventory
            local resources
            resources=$(jq -c --arg service "$service" --arg type "$resource_type" '
                .accounts[0].regions[0].services[$service][$type][]?
            ' "$aws_inventory" 2>/dev/null || echo "")

            [[ -z "$resources" ]] && continue

            while IFS= read -r resource; do
                [[ -z "$resource" ]] && continue

                local resource_id
                resource_id=$(get_resource_identifier "$tf_resource_type" "$resource")

                [[ "$resource_id" == "unknown" ]] || [[ -z "$resource_id" ]] && continue

                # Check if this resource is managed by Terraform
                if ! echo "$managed_ids" | grep -Fxq "$resource_id"; then
                    # Unmanaged resource found!
                    ((total_unmanaged++))

                    local tf_name
                    tf_name=$(generate_terraform_name "$resource_id")

                    local import_cmd="terraform import ${tf_resource_type}.${tf_name} ${resource_id}"

                    # Add to unmanaged resources JSON
                    local unmanaged_resource
                    unmanaged_resource=$(echo "$resource" | jq -c \
                        --arg id "$resource_id" \
                        --arg tf_type "$tf_resource_type" \
                        --arg tf_addr "${tf_resource_type}.${tf_name}" \
                        --arg import_cmd "$import_cmd" \
                        '{
                            resource_id: $id,
                            resource_type_terraform: $tf_type,
                            terraform_address: $tf_addr,
                            import_command: $import_cmd,
                            resource_data: .
                        }')

                    # Append to service array
                    jq --arg service "$service" \
                       --argjson resource "$unmanaged_resource" \
                       '.by_service[$service] += [$resource] | .total_count += 1' \
                       "$unmanaged_file" > "${unmanaged_file}.tmp" && \
                       mv "${unmanaged_file}.tmp" "$unmanaged_file"
                fi
            done <<< "$resources"
        done <<< "$resource_types"
    done

    cat "$unmanaged_file"
    rm -f "$unmanaged_file"
}

# Generate import plan with priority
generate_import_plan() {
    local unmanaged_resources=$1

    log_info "Generating prioritized import plan..."

    local high_priority=()
    local medium_priority=()
    local low_priority=()

    # Iterate through unmanaged resources and categorize by priority
    while IFS= read -r import_cmd; do
        [[ -z "$import_cmd" ]] && continue

        # Extract resource type from import command
        local resource_type
        resource_type=$(echo "$import_cmd" | awk '{print $3}' | cut -d'.' -f1)

        local priority
        priority=$(get_import_priority "$resource_type")

        case "$priority" in
            high) high_priority+=("$import_cmd") ;;
            medium) medium_priority+=("$import_cmd") ;;
            low) low_priority+=("$import_cmd") ;;
        esac
    done < <(echo "$unmanaged_resources" | jq -r '.by_service[].[] | .import_command' 2>/dev/null)

    # Build import plan JSON (use temp files to avoid argument list too long)
    local high_file="/tmp/terraform_audit_high_$$.json"
    local medium_file="/tmp/terraform_audit_medium_$$.json"
    local low_file="/tmp/terraform_audit_low_$$.json"

    printf '%s\n' "${high_priority[@]}" | jq -R . | jq -s . > "$high_file" 2>/dev/null || echo "[]" > "$high_file"
    printf '%s\n' "${medium_priority[@]}" | jq -R . | jq -s . > "$medium_file" 2>/dev/null || echo "[]" > "$medium_file"
    printf '%s\n' "${low_priority[@]}" | jq -R . | jq -s . > "$low_file" 2>/dev/null || echo "[]" > "$low_file"

    jq -n \
        --slurpfile high "$high_file" \
        --slurpfile medium "$medium_file" \
        --slurpfile low "$low_file" \
        '{
            high_priority: $high[0],
            medium_priority: $medium[0],
            low_priority: $low[0]
        }'

    rm -f "$high_file" "$medium_file" "$low_file"
}

# Main audit function
run_audit() {
    local start_time
    start_time=$(date +%s)

    log_info "========================================"
    log_info "Terraform State Audit v${SCRIPT_VERSION}"
    log_info "========================================"
    log_info "AWS Inventory: $AWS_INVENTORY"
    log_info "Output file: $OUTPUT_FILE"
    log_info "========================================"

    # Find Terraform workspaces
    local workspaces
    workspaces=$(find_terraform_workspaces)

    local workspace_count
    workspace_count=$(echo "$workspaces" | wc -l)
    log_info "Found $workspace_count Terraform workspace(s)"

    # Parse all Terraform states
    log_info "Parsing Terraform state files..."
    local all_states_file="/tmp/terraform_audit_states_$$.json"
    echo "[]" > "$all_states_file"

    while IFS= read -r workspace; do
        log_debug "Processing workspace: $workspace"
        local state
        state=$(parse_terraform_state "$workspace")
        echo "$state" > "/tmp/terraform_audit_state_tmp_$$.json"
        jq -s '.[0] + [.[1]]' "$all_states_file" "/tmp/terraform_audit_state_tmp_$$.json" > "${all_states_file}.new"
        mv "${all_states_file}.new" "$all_states_file"
        rm -f "/tmp/terraform_audit_state_tmp_$$.json"
    done <<< "$workspaces"

    # Build combined Terraform state JSON
    local tf_state_json
    tf_state_json=$(jq '{workspaces: .}' "$all_states_file")
    rm -f "$all_states_file"

    # Count total managed resources
    local total_managed
    total_managed=$(echo "$tf_state_json" | jq '[.workspaces[].resources[].instances[]] | length')
    log_info "Total Terraform-managed resources: $total_managed"

    # Compare against AWS inventory
    local unmanaged_resources
    unmanaged_resources=$(compare_resources "$tf_state_json" "$AWS_INVENTORY")

    local total_unmanaged
    total_unmanaged=$(echo "$unmanaged_resources" | jq '.total_count')
    log_info "Total unmanaged resources: $total_unmanaged"

    # Generate import plan
    local import_plan
    import_plan=$(generate_import_plan "$unmanaged_resources")

    # Calculate summary
    local total_aws
    total_aws=$(jq '[.accounts[].regions[].services | .. | objects | select(has("arn") or has("id")) ] | length' "$AWS_INVENTORY" 2>/dev/null || echo "0")

    local coverage_pct=0
    if [[ "$total_aws" -gt 0 ]]; then
        coverage_pct=$(echo "scale=2; ($total_managed / $total_aws) * 100" | bc)
    fi

    # Build final report
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Build final report (use temp files to avoid argument list too long)
    local tf_state_file="/tmp/terraform_audit_tfstate_$$.json"
    local unmanaged_file="/tmp/terraform_audit_unmanaged_final_$$.json"
    local import_plan_file="/tmp/terraform_audit_import_plan_$$.json"
    local workspaces_file="/tmp/terraform_audit_workspaces_$$.json"

    echo "$tf_state_json" > "$tf_state_file"
    echo "$unmanaged_resources" > "$unmanaged_file"
    echo "$import_plan" > "$import_plan_file"
    echo "$workspaces" | jq -R . | jq -s . > "$workspaces_file"

    local report
    report=$(jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg inventory "$AWS_INVENTORY" \
        --arg version "$SCRIPT_VERSION" \
        --arg account "$(jq -r '.metadata.master_account_id' "$AWS_INVENTORY")" \
        --slurpfile workspaces "$workspaces_file" \
        --argjson total_aws "$total_aws" \
        --argjson total_managed "$total_managed" \
        --argjson total_unmanaged "$total_unmanaged" \
        --argjson coverage "$coverage_pct" \
        --slurpfile tf_state "$tf_state_file" \
        --slurpfile unmanaged "$unmanaged_file" \
        --slurpfile import_plan "$import_plan_file" \
        '{
            metadata: {
                generated_at: $timestamp,
                terraform_workspaces: $workspaces[0],
                aws_inventory_file: $inventory,
                account_id: $account,
                version: $version
            },
            summary: {
                total_aws_resources: $total_aws,
                total_terraform_managed: $total_managed,
                total_unmanaged: $total_unmanaged,
                total_orphaned: 0,
                coverage_percentage: $coverage
            },
            terraform_state: $tf_state[0],
            unmanaged_resources: $unmanaged[0],
            orphaned_resources: {
                by_workspace: {},
                total_count: 0
            },
            import_plan: $import_plan[0]
        }')

    rm -f "$tf_state_file" "$unmanaged_file" "$import_plan_file" "$workspaces_file"

    # Write report
    echo "$report" | jq '.' > "$OUTPUT_FILE"

    # Generate import script if requested
    if [[ "$GENERATE_IMPORTS" == "true" ]]; then
        local import_script="${OUTPUT_FILE%.json}-imports.sh"
        log_info "Generating import script: $import_script"

        cat > "$import_script" << 'EOF'
#!/bin/bash
# Terraform Import Script
# Generated by terraform-audit.sh
#
# This script contains terraform import commands for all unmanaged resources
# Review and execute in appropriate Terraform workspace

set -euo pipefail

echo "=== HIGH PRIORITY IMPORTS ==="
EOF

        echo "$import_plan" | jq -r '.high_priority[]' >> "$import_script"

        cat >> "$import_script" << 'EOF'

echo ""
echo "=== MEDIUM PRIORITY IMPORTS ==="
EOF

        echo "$import_plan" | jq -r '.medium_priority[]' >> "$import_script"

        cat >> "$import_script" << 'EOF'

echo ""
echo "=== LOW PRIORITY IMPORTS ==="
EOF

        echo "$import_plan" | jq -r '.low_priority[]' >> "$import_script"

        chmod +x "$import_script"
        log_success "Import script created: $import_script"
    fi

    log_success "========================================"
    log_success "Audit completed in ${duration} seconds"
    log_success "Report saved to: $OUTPUT_FILE"
    log_success "Coverage: ${coverage_pct}%"
    log_success "Unmanaged resources: $total_unmanaged"
    log_success "========================================"
}

# Main execution
main() {
    parse_args "$@"
    check_prerequisites
    run_audit
}

# Run main function
main "$@"
