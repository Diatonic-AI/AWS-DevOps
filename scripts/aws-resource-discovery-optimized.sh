#!/bin/bash
#
# AWS Resource Discovery Script - OPTIMIZED VERSION
# Comprehensive inventory of all AWS resources across organization accounts and regions
# Optimized for performance with parallel processing, caching, and improved data handling
#
# Usage:
#   ./aws-resource-discovery-optimized.sh [options]
#
# Options:
#   --regions REGION1,REGION2    Comma-separated list of regions (default: us-east-1,us-east-2)
#   --account ACCOUNT_ID         Scan specific account only (default: all accounts)
#   --output FILE                Output file path (default: ./aws-inventory.json)
#   --exclude-amplify            Exclude Amplify resources (default: true)
#   --include-global             Include global services (IAM, CloudFront, etc.) (default: true)
#   --max-parallel NUM           Maximum parallel processes (default: 8)
#   --cache-ttl SECONDS          Cache TTL in seconds (default: 3600)
#   --verbose                    Enable verbose output
#   --help                       Display this help message
#
# Example:
#   ./aws-resource-discovery-optimized.sh --regions us-east-1,us-east-2 --max-parallel 12
#

set -euo pipefail

# Script metadata
SCRIPT_VERSION="2.0.0-optimized"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
DEFAULT_REGIONS="us-east-1,us-east-2"
DEFAULT_OUTPUT="${PROJECT_ROOT}/aws-inventory.json"
EXCLUDE_AMPLIFY=true
INCLUDE_GLOBAL=true
MAX_PARALLEL=8
CACHE_TTL=3600
VERBOSE=false
SPECIFIC_ACCOUNT=""

# Directories for optimized processing
TEMP_DIR="/tmp/aws-discovery-$$"
CACHE_DIR="/tmp/aws-discovery-cache"
WORK_DIR="${TEMP_DIR}/work"
RESULTS_DIR="${TEMP_DIR}/results"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
            --regions)
                DEFAULT_REGIONS="$2"
                shift 2
                ;;
            --account)
                SPECIFIC_ACCOUNT="$2"
                shift 2
                ;;
            --output)
                DEFAULT_OUTPUT="$2"
                shift 2
                ;;
            --exclude-amplify)
                EXCLUDE_AMPLIFY=true
                shift
                ;;
            --include-amplify)
                EXCLUDE_AMPLIFY=false
                shift
                ;;
            --include-global)
                INCLUDE_GLOBAL=true
                shift
                ;;
            --max-parallel)
                MAX_PARALLEL="$2"
                shift 2
                ;;
            --cache-ttl)
                CACHE_TTL="$2"
                shift 2
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

# Setup working directories
setup_directories() {
    log_info "Setting up working directories..."
    mkdir -p "$TEMP_DIR" "$CACHE_DIR" "$WORK_DIR" "$RESULTS_DIR"
    
    # Cleanup trap
    trap cleanup EXIT
}

# Cleanup function (only run in main process)
cleanup() {
    # Only cleanup in main process, not subshells
    if [[ "$$" == "$BASHPID" ]] && [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
}

# Check AWS CLI availability
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it first: sudo apt install jq"
        exit 1
    fi

    # Test AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured or invalid."
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Process control for parallel execution
sem() {
    while [[ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]]; do
        sleep 0.1
    done
}

# Cache management functions
get_cache_key() {
    local account_id="$1"
    local region="$2" 
    local service="$3"
    echo "${account_id}_${region}_${service}_$(date +%Y%m%d%H)"
}

is_cache_valid() {
    local cache_file="$1"
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        [[ $cache_age -lt $CACHE_TTL ]]
    else
        return 1
    fi
}

# Optimized AWS service discovery functions with caching
discover_service_cached() {
    local account_id="$1"
    local region="$2"
    local service="$3"
    local discover_function="$4"
    
    local cache_key
    cache_key=$(get_cache_key "$account_id" "$region" "$service")
    local cache_file="${CACHE_DIR}/${cache_key}.json"
    
    if is_cache_valid "$cache_file"; then
        log_debug "Using cached data for ${service} in ${region}"
        cat "$cache_file"
    else
        log_debug "Fetching fresh data for ${service} in ${region}"
        local result
        if result=$($discover_function "$region" 2>/dev/null); then
            echo "$result" > "$cache_file"
            echo "$result"
        else
            echo "[]"
        fi
    fi
}

# Optimized discovery functions (stream processing, no large argument lists)
discover_ec2_instances() {
    local region=$1
    aws ec2 describe-instances \
        --region "$region" \
        --output json \
        --no-paginate \
        --query 'Reservations[].Instances[]' 2>/dev/null | \
    jq -c '.[] | {
        instance_id: .InstanceId,
        instance_type: .InstanceType,
        state: .State.Name,
        launch_time: .LaunchTime,
        name: (.Tags[]? | select(.Key == "Name") | .Value) // "N/A"
    }' | jq -s '.' || echo "[]"
}

discover_lambda_functions() {
    local region=$1
    aws lambda list-functions \
        --region "$region" \
        --output json \
        --no-paginate 2>/dev/null | \
    jq -c '.Functions[] | {
        function_name: .FunctionName,
        runtime: .Runtime,
        last_modified: .LastModified,
        memory_size: .MemorySize,
        timeout: .Timeout,
        arn: .FunctionArn
    }' | jq -s '.' || echo "[]"
}

discover_ecs_clusters() {
    local region=$1
    local cluster_arns
    cluster_arns=$(aws ecs list-clusters --region "$region" --query 'clusterArns[]' --output json 2>/dev/null || echo "[]")
    
    if [[ "$cluster_arns" == "[]" ]]; then
        echo "[]"
        return
    fi
    
    echo "$cluster_arns" | jq -r '.[]' | while read -r cluster_arn; do
        aws ecs describe-clusters \
            --region "$region" \
            --clusters "$cluster_arn" \
            --output json 2>/dev/null | \
        jq -c '.clusters[]? | {
            cluster_name: .clusterName,
            status: .status,
            container_instances: .registeredContainerInstancesCount,
            running_tasks: .runningTasksCount,
            pending_tasks: .pendingTasksCount,
            active_services: .activeServicesCount,
            arn: .clusterArn
        }'
    done | jq -s '.' || echo "[]"
}

discover_ecs_services() {
    local region=$1
    local cluster_arns
    cluster_arns=$(aws ecs list-clusters --region "$region" --query 'clusterArns[]' --output json 2>/dev/null || echo "[]")
    
    if [[ "$cluster_arns" == "[]" ]]; then
        echo "[]"
        return
    fi
    
    echo "$cluster_arns" | jq -r '.[]' | while read -r cluster_arn; do
        aws ecs list-services --region "$region" --cluster "$cluster_arn" --query 'serviceArns[]' --output json 2>/dev/null | \
        jq -r '.[]?' | while read -r service_arn; do
            [[ -n "$service_arn" ]] && aws ecs describe-services \
                --region "$region" \
                --cluster "$cluster_arn" \
                --services "$service_arn" \
                --output json 2>/dev/null | \
            jq -c '.services[]? | {
                service_name: .serviceName,
                status: .status,
                desired_count: .desiredCount,
                running_count: .runningCount,
                pending_count: .pendingCount,
                launch_type: .launchType,
                arn: .serviceArn
            }'
        done
    done | jq -s '.' || echo "[]"
}

discover_dynamodb_tables() {
    local region=$1
    aws dynamodb list-tables --region "$region" --output json 2>/dev/null | \
    jq -r '.TableNames[]?' | while read -r table_name; do
        [[ -n "$table_name" ]] && aws dynamodb describe-table \
            --region "$region" \
            --table-name "$table_name" \
            --output json 2>/dev/null | \
        jq -c '.Table | {
            table_name: .TableName,
            status: .TableStatus,
            item_count: .ItemCount,
            size_bytes: .TableSizeBytes,
            created_at: .CreationDateTime,
            arn: .TableArn
        }'
    done | jq -s '.' || echo "[]"
}

discover_s3_buckets() {
    local target_region=$1
    aws s3api list-buckets --output json 2>/dev/null | \
    jq -r '.Buckets[]?.Name' | while read -r bucket_name; do
        [[ -n "$bucket_name" ]] || continue
        
        # Get bucket location
        local bucket_region
        bucket_region=$(aws s3api get-bucket-location --bucket "$bucket_name" --query 'LocationConstraint' --output text 2>/dev/null || echo "us-east-1")
        
        # AWS returns null/None for us-east-1
        if [[ "$bucket_region" == "None" ]] || [[ "$bucket_region" == "null" ]] || [[ -z "$bucket_region" ]]; then
            bucket_region="us-east-1"
        fi
        
        # Only include if matches target region
        if [[ "$bucket_region" == "$target_region" ]]; then
            # Check if Amplify-related (lightweight check)
            local is_amplify=false
            if aws s3api get-bucket-tagging --bucket "$bucket_name" --output json 2>/dev/null | \
               jq -e '.TagSet[]? | select(.Key == "amplify:app_id")' >/dev/null 2>&1; then
                is_amplify=true
            fi
            
            # Skip if Amplify and exclusion is enabled
            if [[ "$EXCLUDE_AMPLIFY" == "true" ]] && [[ "$is_amplify" == "true" ]]; then
                continue
            fi
            
            jq -n --arg bucket_name "$bucket_name" --arg region "$bucket_region" --argjson is_amplify "$is_amplify" \
                '{bucket_name: $bucket_name, region: $region, is_amplify: $is_amplify}'
        fi
    done | jq -s '.' || echo "[]"
}

discover_rds_instances() {
    local region=$1
    aws rds describe-db-instances \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.DBInstances[]? | {
        db_instance_id: .DBInstanceIdentifier,
        instance_class: .DBInstanceClass,
        engine: .Engine,
        engine_version: .EngineVersion,
        status: .DBInstanceStatus,
        allocated_storage_gb: .AllocatedStorage,
        arn: .DBInstanceArn
    }' | jq -s '.' || echo "[]"
}

discover_vpcs() {
    local region=$1
    aws ec2 describe-vpcs \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.Vpcs[]? | {
        vpc_id: .VpcId,
        cidr_block: .CidrBlock,
        state: .State,
        is_default: .IsDefault,
        name: (.Tags[]? | select(.Key == "Name") | .Value) // "N/A"
    }' | jq -s '.' || echo "[]"
}

discover_load_balancers() {
    local region=$1
    
    # ALB/NLB
    local albs
    albs=$(aws elbv2 describe-load-balancers \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.LoadBalancers[]? | {
        name: .LoadBalancerName,
        type: .Type,
        scheme: .Scheme,
        state: .State.Code,
        dns_name: .DNSName,
        arn: .LoadBalancerArn
    }' | jq -s '.' || echo "[]")
    
    # Classic ELB
    local clbs
    clbs=$(aws elb describe-load-balancers \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.LoadBalancerDescriptions[]? | {
        name: .LoadBalancerName,
        type: "classic",
        scheme: .Scheme,
        state: "active",
        dns_name: .DNSName,
        arn: "N/A"
    }' | jq -s '.' || echo "[]")
    
    jq -s 'add' <(echo "$albs") <(echo "$clbs") 2>/dev/null || echo "[]"
}

discover_api_gateways() {
    local region=$1
    
    # REST APIs
    local rest_apis
    rest_apis=$(aws apigateway get-rest-apis \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.items[]? | {
        api_id: .id,
        name: .name,
        type: "REST",
        created_date: .createdDate,
        api_key_source: .apiKeySource
    }' | jq -s '.' || echo "[]")
    
    # HTTP APIs (v2)
    local http_apis
    http_apis=$(aws apigatewayv2 get-apis \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.Items[]? | {
        api_id: .ApiId,
        name: .Name,
        type: .ProtocolType,
        created_date: .CreatedDate,
        endpoint: .ApiEndpoint
    }' | jq -s '.' || echo "[]")
    
    jq -s 'add' <(echo "$rest_apis") <(echo "$http_apis") 2>/dev/null || echo "[]"
}

# Additional optimized discovery functions...
discover_ecr_repositories() {
    local region=$1
    aws ecr describe-repositories \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.repositories[]? | {
        repository_name: .repositoryName,
        repository_uri: .repositoryUri,
        created_at: .createdAt,
        tag_mutability: .imageTagMutability,
        arn: .repositoryArn
    }' | jq -s '.' || echo "[]"
}

discover_cognito_user_pools() {
    local region=$1
    aws cognito-idp list-user-pools \
        --region "$region" \
        --max-results 60 \
        --output json 2>/dev/null | \
    jq -c '.UserPools[]? | {
        pool_id: .Id,
        pool_name: .Name,
        created_at: .CreationDate,
        last_modified: .LastModifiedDate
    }' | jq -s '.' || echo "[]"
}

discover_secrets() {
    local region=$1
    aws secretsmanager list-secrets \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.SecretList[]? | {
        secret_name: .Name,
        arn: .ARN,
        created_at: .CreatedDate,
        last_accessed: (.LastAccessedDate // "N/A")
    }' | jq -s '.' || echo "[]"
}

discover_cloudwatch_log_groups() {
    local region=$1
    aws logs describe-log-groups \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.logGroups[]? | {
        log_group_name: .logGroupName,
        created_at: .creationTime,
        stored_bytes: .storedBytes,
        retention_days: .retentionInDays // null
    }' | jq -s '.[0:100]' || echo "[]"  # Limit to first 100
}

discover_sns_topics() {
    local region=$1
    aws sns list-topics \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.Topics[]? | {
        topic_arn: .TopicArn,
        topic_name: (.TopicArn | split(":") | .[-1])
    }' | jq -s '.' || echo "[]"
}

discover_sqs_queues() {
    local region=$1
    aws sqs list-queues \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.QueueUrls[]? | {
        queue_url: .,
        queue_name: (. | split("/") | .[-1])
    }' | jq -s '.' || echo "[]"
}

discover_kms_keys() {
    local region=$1
    aws kms list-keys \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -r '.Keys[]?.KeyId' | head -50 | while read -r key_id; do
        [[ -n "$key_id" ]] && aws kms describe-key \
            --region "$region" \
            --key-id "$key_id" \
            --output json 2>/dev/null | \
        jq -c '.KeyMetadata | {
            key_id: .KeyId,
            arn: .Arn,
            created_at: .CreationDate,
            enabled: .Enabled,
            state: .KeyState,
            manager: .KeyManager
        }'
    done | jq -s '.' || echo "[]"
}

discover_eventbridge_rules() {
    local region=$1
    aws events list-rules \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.Rules[]? | {
        rule_name: .Name,
        state: .State,
        description: (.Description // "N/A"),
        schedule: (.ScheduleExpression // "N/A"),
        event_bus: .EventBusName,
        arn: .Arn
    }' | jq -s '.' || echo "[]"
}

discover_amplify_apps() {
    local region=$1
    
    # Skip if exclusion is enabled
    if [[ "$EXCLUDE_AMPLIFY" == "true" ]]; then
        echo "[]"
        return
    fi
    
    aws amplify list-apps \
        --region "$region" \
        --output json 2>/dev/null | \
    jq -c '.apps[]? | {
        app_id: .appId,
        name: .name,
        default_domain: .defaultDomain,
        repository: .repository,
        platform: .platform,
        created_at: .createTime,
        updated_at: .updateTime,
        arn: .appArn
    }' | jq -s '.' || echo "[]"
}

# Global service discovery functions
discover_cloudfront_distributions() {
    aws cloudfront list-distributions \
        --output json 2>/dev/null | \
    jq -c '.DistributionList.Items[]? | {
        distribution_id: .Id,
        domain_name: .DomainName,
        status: .Status,
        enabled: .Enabled,
        comment: (.Comment // "N/A")
    }' | jq -s '.' || echo "[]"
}

discover_route53_zones() {
    aws route53 list-hosted-zones \
        --output json 2>/dev/null | \
    jq -c '.HostedZones[]? | {
        zone_id: (.Id | split("/") | .[-1]),
        domain_name: .Name,
        is_private: .Config.PrivateZone,
        record_count: .ResourceRecordSetCount
    }' | jq -s '.' || echo "[]"
}

discover_iam_roles() {
    aws iam list-roles \
        --output json 2>/dev/null | \
    jq -c '.Roles[]? | {
        role_name: .RoleName,
        created_at: .CreateDate,
        arn: .Arn,
        description: (.Description // "N/A")
    }' | jq -s '.[0:100]' || echo "[]"  # Limit to first 100
}

# Parallel service discovery for a region
discover_services_parallel() {
    local account_id="$1"
    local region="$2"
    local result_file="$3"
    
    log_debug "Starting parallel discovery for account $account_id, region $region"
    
    # Ensure result directory exists - with error handling
    local result_dir
    result_dir="$(dirname "$result_file")"
    if ! mkdir -p "$result_dir" 2>/dev/null; then
        log_error "Failed to create result directory: $result_dir"
        echo '{}' > "$result_file"
        return 1
    fi
    
    # Use unique temp directory to avoid conflicts
    local temp_dir="${result_dir}/temp_${account_id}_${region}_$$"
    mkdir -p "$temp_dir"
    
    local temp_files=()
    local services=("ec2" "lambda" "ecs_clusters" "ecs_services" "dynamodb" "s3" "rds" "vpcs" "load_balancers" "api_gateways" "ecr" "cognito" "secrets" "cloudwatch_logs" "sns" "sqs" "kms" "eventbridge" "amplify")
    
    # Pre-create all temp files with empty arrays in the temp directory
    for service in "${services[@]}"; do
        echo "[]" > "${temp_dir}/${service}.json"
        temp_files+=("${temp_dir}/${service}.json")
    done
    
    # Launch parallel service discoveries with error handling
    local pids=()
    discover_service_cached "$account_id" "$region" "ec2" "discover_ec2_instances" > "${temp_dir}/ec2.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "lambda" "discover_lambda_functions" > "${temp_dir}/lambda.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "ecs_clusters" "discover_ecs_clusters" > "${temp_dir}/ecs_clusters.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "ecs_services" "discover_ecs_services" > "${temp_dir}/ecs_services.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "dynamodb" "discover_dynamodb_tables" > "${temp_dir}/dynamodb.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "s3" "discover_s3_buckets" > "${temp_dir}/s3.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "rds" "discover_rds_instances" > "${temp_dir}/rds.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "vpcs" "discover_vpcs" > "${temp_dir}/vpcs.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "load_balancers" "discover_load_balancers" > "${temp_dir}/load_balancers.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "api_gateways" "discover_api_gateways" > "${temp_dir}/api_gateways.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "ecr" "discover_ecr_repositories" > "${temp_dir}/ecr.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "cognito" "discover_cognito_user_pools" > "${temp_dir}/cognito.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "secrets" "discover_secrets" > "${temp_dir}/secrets.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "cloudwatch_logs" "discover_cloudwatch_log_groups" > "${temp_dir}/cloudwatch_logs.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "sns" "discover_sns_topics" > "${temp_dir}/sns.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "sqs" "discover_sqs_queues" > "${temp_dir}/sqs.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "kms" "discover_kms_keys" > "${temp_dir}/kms.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "eventbridge" "discover_eventbridge_rules" > "${temp_dir}/eventbridge.json" 2>/dev/null &
    pids+=($!)
    discover_service_cached "$account_id" "$region" "amplify" "discover_amplify_apps" > "${temp_dir}/amplify.json" 2>/dev/null &
    pids+=($!)
    
    # Wait for all background processes
    local failed_count=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            failed_count=$((failed_count + 1))
        fi
    done
    
    if [[ $failed_count -gt 0 ]]; then
        log_warn "$failed_count service discoveries failed for account $account_id, region $region"
    fi
    
    # Combine all results into structured format using temp files
    if jq -n \
        --arg region "$region" \
        --slurpfile ec2_instances "${temp_dir}/ec2.json" \
        --slurpfile ecs_clusters "${temp_dir}/ecs_clusters.json" \
        --slurpfile ecs_services "${temp_dir}/ecs_services.json" \
        --slurpfile lambda_functions "${temp_dir}/lambda.json" \
        --slurpfile s3_buckets "${temp_dir}/s3.json" \
        --slurpfile dynamodb_tables "${temp_dir}/dynamodb.json" \
        --slurpfile rds_instances "${temp_dir}/rds.json" \
        --slurpfile vpcs "${temp_dir}/vpcs.json" \
        --slurpfile load_balancers "${temp_dir}/load_balancers.json" \
        --slurpfile api_gateways "${temp_dir}/api_gateways.json" \
        --slurpfile ecr_repositories "${temp_dir}/ecr.json" \
        --slurpfile cognito_user_pools "${temp_dir}/cognito.json" \
        --slurpfile secrets "${temp_dir}/secrets.json" \
        --slurpfile cloudwatch_log_groups "${temp_dir}/cloudwatch_logs.json" \
        --slurpfile sns_topics "${temp_dir}/sns.json" \
        --slurpfile sqs_queues "${temp_dir}/sqs.json" \
        --slurpfile kms_keys "${temp_dir}/kms.json" \
        --slurpfile eventbridge_rules "${temp_dir}/eventbridge.json" \
        --slurpfile amplify_apps "${temp_dir}/amplify.json" \
        '{
            region: $region,
            services: {
                compute: {
                    ec2_instances: $ec2_instances[0],
                    ecs_clusters: $ecs_clusters[0],
                    ecs_services: $ecs_services[0],
                    lambda_functions: $lambda_functions[0]
                },
                storage: {
                    s3_buckets: $s3_buckets[0],
                    ebs_volumes: [],
                    efs_filesystems: []
                },
                database: {
                    dynamodb_tables: $dynamodb_tables[0],
                    rds_instances: $rds_instances[0],
                    rds_clusters: []
                },
                networking: {
                    vpcs: $vpcs[0],
                    subnets: [],
                    security_groups: [],
                    load_balancers: $load_balancers[0],
                    api_gateways: $api_gateways[0],
                    cloudfront_distributions: []
                },
                containers: {
                    ecr_repositories: $ecr_repositories[0]
                },
                security: {
                    iam_roles: [],
                    iam_policies: [],
                    secrets: $secrets[0],
                    kms_keys: $kms_keys[0]
                },
                dns: {
                    route53_zones: [],
                    route53_records: []
                },
                auth: {
                    cognito_user_pools: $cognito_user_pools[0],
                    cognito_identity_pools: []
                },
                monitoring: {
                    cloudwatch_alarms: [],
                    cloudwatch_log_groups: $cloudwatch_log_groups[0],
                    eventbridge_rules: $eventbridge_rules[0]
                },
                messaging: {
                    sns_topics: $sns_topics[0],
                    sqs_queues: $sqs_queues[0]
                },
                frontend: {
                    amplify_apps: $amplify_apps[0]
                }
            }
        }' > "$result_file" 2>/dev/null; then
        log_debug "Successfully created region result file: $result_file"
    else
        log_error "Failed to create region result file: $result_file"
        echo '{}' > "$result_file"
    fi
    
    # Cleanup temp directory
    rm -rf "$temp_dir" 2>/dev/null || true
    
    log_debug "Completed discovery for account $account_id, region $region"
}

# Scan global services (optimized, no large argument lists)
scan_global_services() {
    local result_file="$1"
    log_info "Scanning global services..."
    
    # Ensure result directory exists
    local result_dir
    result_dir="$(dirname "$result_file")"
    if ! mkdir -p "$result_dir" 2>/dev/null; then
        log_error "Failed to create result directory: $result_dir"
        echo '{}' > "$result_file"
        return 1
    fi
    
    # Use unique temp directory
    local temp_dir="${result_dir}/temp_global_$$"
    mkdir -p "$temp_dir"
    
    local global_services=("cloudfront" "iam" "route53")
    local temp_files=()
    for service in "${global_services[@]}"; do
        echo "[]" > "${temp_dir}/${service}.json"
        temp_files+=("${temp_dir}/${service}.json")
    done
    
    # Launch parallel global service discoveries with error handling
    local pids=()
    discover_cloudfront_distributions > "${temp_dir}/cloudfront.json" 2>/dev/null &
    pids+=($!)
    discover_iam_roles > "${temp_dir}/iam.json" 2>/dev/null &
    pids+=($!)
    discover_route53_zones > "${temp_dir}/route53.json" 2>/dev/null &
    pids+=($!)
    
    # Wait for all processes
    local failed_count=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            failed_count=$((failed_count + 1))
        fi
    done
    
    if [[ $failed_count -gt 0 ]]; then
        log_warn "$failed_count global service discoveries failed"
    fi
    
    # Combine results with error handling
    if jq -n \
        --slurpfile cloudfront "${temp_dir}/cloudfront.json" \
        --slurpfile iam_roles "${temp_dir}/iam.json" \
        --slurpfile route53_zones "${temp_dir}/route53.json" \
        '{
            region: "global",
            services: {
                compute: {
                    ec2_instances: [],
                    ecs_clusters: [],
                    ecs_services: [],
                    lambda_functions: []
                },
                storage: {
                    s3_buckets: [],
                    ebs_volumes: [],
                    efs_filesystems: []
                },
                database: {
                    dynamodb_tables: [],
                    rds_instances: [],
                    rds_clusters: []
                },
                networking: {
                    vpcs: [],
                    subnets: [],
                    security_groups: [],
                    load_balancers: [],
                    api_gateways: [],
                    cloudfront_distributions: $cloudfront[0]
                },
                containers: {
                    ecr_repositories: []
                },
                security: {
                    iam_roles: $iam_roles[0],
                    iam_policies: [],
                    secrets: [],
                    kms_keys: []
                },
                dns: {
                    route53_zones: $route53_zones[0],
                    route53_records: []
                },
                auth: {
                    cognito_user_pools: [],
                    cognito_identity_pools: []
                },
                monitoring: {
                    cloudwatch_alarms: [],
                    cloudwatch_log_groups: []
                },
                messaging: {
                    sns_topics: [],
                    sqs_queues: []
                }
            }
        }' > "$result_file" 2>/dev/null; then
        log_debug "Successfully created global services result file: $result_file"
    else
        log_error "Failed to create global services result file: $result_file"
        echo '{}' > "$result_file"
    fi
    
    # Cleanup temp directory
    rm -rf "$temp_dir" 2>/dev/null || true
}

# Get organization information
get_organization_info() {
    log_info "Fetching AWS Organization information..."

    local org_info
    org_info=$(aws organizations describe-organization 2>/dev/null || echo "{}")

    if [[ "$org_info" == "{}" ]]; then
        log_warn "Not in an AWS Organization or no access. Will scan current account only."
        ORG_ID="N/A"
        MASTER_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    else
        ORG_ID=$(echo "$org_info" | jq -r '.Organization.Id')
        MASTER_ACCOUNT=$(echo "$org_info" | jq -r '.Organization.MasterAccountId')
        log_success "Organization ID: $ORG_ID"
    fi
}

# Get all accounts in organization
get_accounts() {
    log_info "Fetching organization accounts..."

    if [[ -n "$SPECIFIC_ACCOUNT" ]]; then
        log_info "Scanning specific account: $SPECIFIC_ACCOUNT"
        jq -n --arg account_id "$SPECIFIC_ACCOUNT" '[{Id: $account_id, Name: "Specific Account", Status: "ACTIVE"}]'
        return
    fi

    local accounts
    accounts=$(aws organizations list-accounts --query 'Accounts[?Status==`ACTIVE`].[Id,Name,Status]' --output json 2>/dev/null || echo "[]")

    if [[ "$accounts" == "[]" ]]; then
        # Fallback to current account
        local current_account
        current_account=$(aws sts get-caller-identity --query Account --output text)
        jq -n --arg account_id "$current_account" '[{Id: $account_id, Name: "Current Account", Status: "ACTIVE"}]'
    else
        # Transform to proper JSON format
        echo "$accounts" | jq '[.[] | {Id: .[0], Name: .[1], Status: .[2]}]'
    fi
}

# Check if we can access a specific account
check_account_access() {
    local account_id=$1
    local current_account
    current_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
    
    if [[ "$current_account" == "$account_id" ]]; then
        return 0  # We have direct access
    else
        log_warn "Cannot access account $account_id (current: $current_account) - skipping cross-account scan"
        return 1  # Cross-account access not configured
    fi
}

# Scan a single account (optimized with parallel region processing)
scan_account() {
    local account_id=$1
    local account_name=$2

    log_info "===== Scanning Account: $account_name ($account_id) ====="
    
    # Check if we can access this account
    if ! check_account_access "$account_id"; then
        # Ensure RESULTS_DIR exists before writing
        mkdir -p "$RESULTS_DIR" 2>/dev/null || true
        
        # Create empty account file for failed access
        local account_result="${RESULTS_DIR}/account_${account_id}.json"
        jq -n \
            --arg account_id "$account_id" \
            --arg account_name "$account_name" \
            '{
                account_id: $account_id,
                account_name: $account_name,
                regions: [],
                access_error: "Cross-account access not configured"
            }' > "$account_result"
        log_success "Completed scanning account: $account_name ($account_id) [ACCESS DENIED]"
        return 0
    fi

    # Ensure RESULTS_DIR exists for parallel writes
    mkdir -p "$RESULTS_DIR" 2>/dev/null || true
    
    # Parse regions
    IFS=',' read -ra REGIONS <<< "$DEFAULT_REGIONS"

    local regions_files=()
    
    # Scan each region in parallel
    for region in "${REGIONS[@]}"; do
        sem  # Wait for available slot
        local region_result="${RESULTS_DIR}/account_${account_id}_region_${region}.json"
        regions_files+=("$region_result")
        
        (
            discover_services_parallel "$account_id" "$region" "$region_result"
        ) &
    done

    # Add global services if enabled
    if [[ "$INCLUDE_GLOBAL" == "true" ]]; then
        sem  # Wait for available slot
        local global_result="${RESULTS_DIR}/account_${account_id}_global.json"
        regions_files+=("$global_result")
        
        (
            scan_global_services "$global_result"
        ) &
    fi

    # Wait for all regions to complete
    wait

    # Combine all region results into account data
    local regions_data="[]"
    for region_file in "${regions_files[@]}"; do
        if [[ -f "$region_file" ]]; then
            regions_data=$(jq -s '.[0] + [.[1]]' <(echo "$regions_data") "$region_file")
        else
            log_warn "Region file not found: $region_file - using empty data"
        fi
    done

    # Build final account data
    local account_result="${RESULTS_DIR}/account_${account_id}.json"
    jq -n \
        --arg account_id "$account_id" \
        --arg account_name "$account_name" \
        --argjson regions "$regions_data" \
        '{
            account_id: $account_id,
            account_name: $account_name,
            regions: $regions
        }' > "$account_result"
    
    # Verify account file was created
    if [[ ! -f "$account_result" ]] || [[ ! -s "$account_result" ]]; then
        log_error "Failed to create account file: $account_result"
        echo '{}' > "$account_result"
    else
        log_debug "Account file created: $account_result ($(wc -c < "$account_result") bytes)"
    fi

    # Cleanup region files
    for region_file in "${regions_files[@]}"; do
        rm -f "$region_file"
    done

    log_success "Completed scanning account: $account_name ($account_id)"
}

# Main discovery function (optimized)
run_discovery() {
    local start_time
    start_time=$(date +%s)

    log_info "========================================"
    log_info "AWS Resource Discovery Script v${SCRIPT_VERSION}"
    log_info "========================================"
    log_info "Output file: $DEFAULT_OUTPUT"
    log_info "Regions: $DEFAULT_REGIONS"
    log_info "Exclude Amplify: $EXCLUDE_AMPLIFY"
    log_info "Include Global Services: $INCLUDE_GLOBAL"
    log_info "Max Parallel: $MAX_PARALLEL"
    log_info "Cache TTL: ${CACHE_TTL}s"
    log_info "========================================"

    # Get organization info
    get_organization_info

    # Get accounts
    local accounts_json
    accounts_json=$(get_accounts)
    echo "$accounts_json" > "${WORK_DIR}/accounts.json"

    local account_count
    account_count=$(echo "$accounts_json" | jq 'length')
    log_info "Found $account_count account(s) to scan"

    # Scan accounts in parallel (avoid subshell pipeline so wait() works)
    while read -r account; do
        sem  # Wait for available slot
        
        local account_id
        local account_name
        account_id=$(echo "$account" | jq -r '.Id')
        account_name=$(echo "$account" | jq -r '.Name')

        (
            scan_account "$account_id" "$account_name"
        ) &
    done < <(echo "$accounts_json" | jq -c '.[]')

    # Wait for all accounts to complete
    wait

    # Combine all account results
    local all_accounts="[]"
    local account_files_found=0
    
    log_debug "Looking for account files in: ${RESULTS_DIR}"
    
    for account_file in "${RESULTS_DIR}"/account_*.json; do
        # Skip if wildcard didn't match any files
        if [[ ! -e "$account_file" ]]; then
            continue
        fi
        
        account_files_found=$((account_files_found + 1))
        
        if [[ -f "$account_file" ]] && [[ -s "$account_file" ]]; then
            log_debug "Processing account file: $account_file ($(wc -c < "$account_file") bytes)"
            local account_data
            account_data=$(cat "$account_file")
            
            # Validate JSON before combining
            if echo "$account_data" | jq empty 2>/dev/null; then
                all_accounts=$(jq -s '.[0] + [.[1]]' <(echo "$all_accounts") <(echo "$account_data"))
                log_debug "Successfully combined account data"
            else
                log_warn "Invalid JSON in account file: $account_file"
            fi
        else
            log_warn "Account file missing or empty: $account_file"
        fi
    done
    
    log_info "Found $account_files_found account files to process"

    # Build metadata
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    local metadata
    metadata=$(jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg org_id "$ORG_ID" \
        --arg master_account "$MASTER_ACCOUNT" \
        --arg regions "$DEFAULT_REGIONS" \
        --arg version "$SCRIPT_VERSION" \
        --arg duration "$duration" \
        --slurpfile accounts "${WORK_DIR}/accounts.json" \
        '{
            generated_at: $timestamp,
            organization_id: $org_id,
            master_account_id: $master_account,
            regions_scanned: ($regions | split(",")),
            accounts_scanned: $accounts[0],
            version: $version,
            scan_duration_seconds: ($duration | tonumber)
        }')

    # Calculate summary (placeholder - can be enhanced)
    local summary='{
        "total_resources": 0,
        "resources_by_service": {},
        "resources_by_region": {},
        "resources_by_account": {},
        "estimated_monthly_cost": null
    }'

    # Build final inventory using temp files to avoid argument issues
    echo "$metadata" > "${WORK_DIR}/metadata.json"
    echo "$summary" > "${WORK_DIR}/summary.json"
    echo "$all_accounts" > "${WORK_DIR}/all_accounts.json"

    jq -n \
        --slurpfile metadata "${WORK_DIR}/metadata.json" \
        --slurpfile summary "${WORK_DIR}/summary.json" \
        --slurpfile accounts "${WORK_DIR}/all_accounts.json" \
        '{
            metadata: $metadata[0],
            summary: $summary[0],
            accounts: $accounts[0]
        }' > "$DEFAULT_OUTPUT"

    log_success "========================================"
    log_success "Discovery completed in ${duration} seconds"
    log_success "Inventory saved to: $DEFAULT_OUTPUT"
    log_success "Cache directory: $CACHE_DIR"
    log_success "========================================"
}

# Main execution
main() {
    parse_args "$@"
    setup_directories
    check_prerequisites
    run_discovery
}

# Run main function
main "$@"