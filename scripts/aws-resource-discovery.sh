#!/bin/bash
#
# AWS Resource Discovery Script
# Comprehensive inventory of all AWS resources across organization accounts and regions
# Excludes Amplify frontend/backend deployments
#
# Usage:
#   ./aws-resource-discovery.sh [options]
#
# Options:
#   --regions REGION1,REGION2    Comma-separated list of regions (default: us-east-1,us-east-2)
#   --account ACCOUNT_ID         Scan specific account only (default: all accounts)
#   --output FILE                Output file path (default: ./aws-inventory.json)
#   --exclude-amplify            Exclude Amplify resources (default: true)
#   --include-global             Include global services (IAM, CloudFront, etc.) (default: true)
#   --parallel                   Run account scans in parallel (default: false)
#   --verbose                    Enable verbose output
#   --help                       Display this help message
#
# Example:
#   ./aws-resource-discovery.sh --regions us-east-1,us-east-2 --output inventory.json
#
# Scheduling with cron:
#   # Run daily at 2 AM
#   0 2 * * * /home/daclab-ai/DEV/AWS-DevOps/scripts/aws-resource-discovery.sh
#

set -euo pipefail

# Script metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
DEFAULT_REGIONS="us-east-1,us-east-2"
DEFAULT_OUTPUT="${PROJECT_ROOT}/aws-inventory.json"
EXCLUDE_AMPLIFY=true
INCLUDE_GLOBAL=true
PARALLEL_EXECUTION=false
VERBOSE=false
SPECIFIC_ACCOUNT=""

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
            --parallel)
                PARALLEL_EXECUTION=true
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
        echo "[{\"Id\": \"$SPECIFIC_ACCOUNT\", \"Name\": \"Specific Account\", \"Status\": \"ACTIVE\"}]"
        return
    fi

    local accounts
    accounts=$(aws organizations list-accounts --query 'Accounts[?Status==`ACTIVE`].[Id,Name,Status]' --output json 2>/dev/null || echo "[]")

    if [[ "$accounts" == "[]" ]]; then
        # Fallback to current account
        local current_account
        current_account=$(aws sts get-caller-identity --query Account --output text)
        echo "[{\"Id\": \"$current_account\", \"Name\": \"Current Account\", \"Status\": \"ACTIVE\"}]"
    else
        # Transform to proper JSON format
        echo "$accounts" | jq '[.[] | {Id: .[0], Name: .[1], Status: .[2]}]'
    fi
}

# Discover EC2 instances in a region
discover_ec2_instances() {
    local region=$1
    log_debug "Discovering EC2 instances in $region..."

    aws ec2 describe-instances \
        --region "$region" \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,LaunchTime,Tags[?Key==`Name`].Value|[0]]' \
        --output json 2>/dev/null | jq '[.[] | {
            instance_id: .[0],
            instance_type: .[1],
            state: .[2],
            launch_time: .[3],
            name: (.[4] // "N/A")
        }]' || echo "[]"
}

# Discover Lambda functions in a region
discover_lambda_functions() {
    local region=$1
    log_debug "Discovering Lambda functions in $region..."

    aws lambda list-functions \
        --region "$region" \
        --query 'Functions[].[FunctionName,Runtime,LastModified,MemorySize,Timeout,FunctionArn]' \
        --output json 2>/dev/null | jq '[.[] | {
            function_name: .[0],
            runtime: .[1],
            last_modified: .[2],
            memory_size: .[3],
            timeout: .[4],
            arn: .[5]
        }]' || echo "[]"
}

# Discover ECS clusters in a region
discover_ecs_clusters() {
    local region=$1
    log_debug "Discovering ECS clusters in $region..."

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
            --query 'clusters[].[clusterName,status,registeredContainerInstancesCount,runningTasksCount,pendingTasksCount,activeServicesCount,clusterArn]' \
            --output json 2>/dev/null || echo "[]"
    done | jq -s 'add | [.[] | {
        cluster_name: .[0],
        status: .[1],
        container_instances: .[2],
        running_tasks: .[3],
        pending_tasks: .[4],
        active_services: .[5],
        arn: .[6]
    }]' || echo "[]"
}

# Discover ECS services in a region
discover_ecs_services() {
    local region=$1
    log_debug "Discovering ECS services in $region..."

    local cluster_arns
    cluster_arns=$(aws ecs list-clusters --region "$region" --query 'clusterArns[]' --output json 2>/dev/null || echo "[]")

    if [[ "$cluster_arns" == "[]" ]]; then
        echo "[]"
        return
    fi

    local all_services="[]"
    echo "$cluster_arns" | jq -r '.[]' | while read -r cluster_arn; do
        local service_arns
        service_arns=$(aws ecs list-services --region "$region" --cluster "$cluster_arn" --query 'serviceArns[]' --output json 2>/dev/null || echo "[]")

        if [[ "$service_arns" != "[]" ]]; then
            aws ecs describe-services \
                --region "$region" \
                --cluster "$cluster_arn" \
                --services $(echo "$service_arns" | jq -r '.[]') \
                --query 'services[].[serviceName,status,desiredCount,runningCount,pendingCount,launchType,serviceArn]' \
                --output json 2>/dev/null || echo "[]"
        else
            echo "[]"
        fi
    done | jq -s 'add | [.[] | {
        service_name: .[0],
        status: .[1],
        desired_count: .[2],
        running_count: .[3],
        pending_count: .[4],
        launch_type: .[5],
        arn: .[6]
    }]' || echo "[]"
}

# Discover DynamoDB tables in a region
discover_dynamodb_tables() {
    local region=$1
    log_debug "Discovering DynamoDB tables in $region..."

    local table_names
    table_names=$(aws dynamodb list-tables --region "$region" --query 'TableNames[]' --output json 2>/dev/null || echo "[]")

    if [[ "$table_names" == "[]" ]]; then
        echo "[]"
        return
    fi

    echo "$table_names" | jq -r '.[]' | while read -r table_name; do
        aws dynamodb describe-table \
            --region "$region" \
            --table-name "$table_name" \
            --query 'Table.[TableName,TableStatus,ItemCount,TableSizeBytes,CreationDateTime,TableArn]' \
            --output json 2>/dev/null || echo "[]"
    done | jq -s '[.[] | {
        table_name: .[0],
        status: .[1],
        item_count: .[2],
        size_bytes: .[3],
        created_at: .[4],
        arn: .[5]
    }]' || echo "[]"
}

# Discover S3 buckets (global, but we'll assign to a region based on location)
discover_s3_buckets() {
    local target_region=$1
    log_debug "Discovering S3 buckets for region $target_region..."

    local buckets
    buckets=$(aws s3api list-buckets --query 'Buckets[].[Name,CreationDate]' --output json 2>/dev/null || echo "[]")

    if [[ "$buckets" == "[]" ]]; then
        echo "[]"
        return
    fi

    echo "$buckets" | jq -r '.[] | .[0]' | while read -r bucket_name; do
        # Get bucket location
        local bucket_region
        bucket_region=$(aws s3api get-bucket-location --bucket "$bucket_name" --query 'LocationConstraint' --output text 2>/dev/null || echo "us-east-1")

        # AWS returns null/None for us-east-1
        if [[ "$bucket_region" == "None" ]] || [[ "$bucket_region" == "null" ]] || [[ -z "$bucket_region" ]]; then
            bucket_region="us-east-1"
        fi

        # Only include if matches target region
        if [[ "$bucket_region" == "$target_region" ]]; then
            local bucket_tags
            bucket_tags=$(aws s3api get-bucket-tagging --bucket "$bucket_name" --output json 2>/dev/null || echo '{"TagSet":[]}')

            # Check if Amplify-related
            local is_amplify=false
            if echo "$bucket_tags" | jq -e '.TagSet[] | select(.Key == "amplify:app_id")' > /dev/null 2>&1; then
                is_amplify=true
            fi

            # Skip if Amplify and exclusion is enabled
            if [[ "$EXCLUDE_AMPLIFY" == "true" ]] && [[ "$is_amplify" == "true" ]]; then
                continue
            fi

            echo "{\"bucket_name\": \"$bucket_name\", \"region\": \"$bucket_region\", \"is_amplify\": $is_amplify}"
        fi
    done | jq -s '.' || echo "[]"
}

# Discover RDS instances in a region
discover_rds_instances() {
    local region=$1
    log_debug "Discovering RDS instances in $region..."

    aws rds describe-db-instances \
        --region "$region" \
        --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,Engine,EngineVersion,DBInstanceStatus,AllocatedStorage,DBInstanceArn]' \
        --output json 2>/dev/null | jq '[.[] | {
            db_instance_id: .[0],
            instance_class: .[1],
            engine: .[2],
            engine_version: .[3],
            status: .[4],
            allocated_storage_gb: .[5],
            arn: .[6]
        }]' || echo "[]"
}

# Discover VPCs in a region
discover_vpcs() {
    local region=$1
    log_debug "Discovering VPCs in $region..."

    aws ec2 describe-vpcs \
        --region "$region" \
        --query 'Vpcs[].[VpcId,CidrBlock,State,IsDefault,Tags[?Key==`Name`].Value|[0]]' \
        --output json 2>/dev/null | jq '[.[] | {
            vpc_id: .[0],
            cidr_block: .[1],
            state: .[2],
            is_default: .[3],
            name: (.[4] // "N/A")
        }]' || echo "[]"
}

# Discover Load Balancers in a region
discover_load_balancers() {
    local region=$1
    log_debug "Discovering Load Balancers in $region..."

    # ALB/NLB
    local albs
    albs=$(aws elbv2 describe-load-balancers \
        --region "$region" \
        --query 'LoadBalancers[].[LoadBalancerName,Type,Scheme,State.Code,DNSName,LoadBalancerArn]' \
        --output json 2>/dev/null | jq '[.[] | {
            name: .[0],
            type: .[1],
            scheme: .[2],
            state: .[3],
            dns_name: .[4],
            arn: .[5]
        }]' || echo "[]")

    # Classic ELB
    local clbs
    clbs=$(aws elb describe-load-balancers \
        --region "$region" \
        --query 'LoadBalancerDescriptions[].[LoadBalancerName,Scheme,DNSName]' \
        --output json 2>/dev/null | jq '[.[] | {
            name: .[0],
            type: "classic",
            scheme: .[1],
            state: "active",
            dns_name: .[2],
            arn: "N/A"
        }]' || echo "[]")

    jq -s 'add' <(echo "$albs") <(echo "$clbs") || echo "[]"
}

# Discover API Gateways in a region
discover_api_gateways() {
    local region=$1
    log_debug "Discovering API Gateways in $region..."

    # REST APIs
    local rest_apis
    rest_apis=$(aws apigateway get-rest-apis \
        --region "$region" \
        --query 'items[].[id,name,createdDate,apiKeySource]' \
        --output json 2>/dev/null | jq '[.[] | {
            api_id: .[0],
            name: .[1],
            type: "REST",
            created_date: .[2],
            api_key_source: .[3]
        }]' || echo "[]")

    # HTTP APIs (v2)
    local http_apis
    http_apis=$(aws apigatewayv2 get-apis \
        --region "$region" \
        --query 'Items[].[ApiId,Name,ProtocolType,CreatedDate,ApiEndpoint]' \
        --output json 2>/dev/null | jq '[.[] | {
            api_id: .[0],
            name: .[1],
            type: .[2],
            created_date: .[3],
            endpoint: .[4]
        }]' || echo "[]")

    jq -s 'add' <(echo "$rest_apis") <(echo "$http_apis") || echo "[]"
}

# Discover CloudFront distributions (global service)
discover_cloudfront_distributions() {
    log_debug "Discovering CloudFront distributions..."

    local result
    result=$(aws cloudfront list-distributions \
        --query 'DistributionList.Items[].[Id,DomainName,Status,Enabled,Comment]' \
        --output json 2>/dev/null || echo "null")

    if [[ "$result" == "null" ]] || [[ -z "$result" ]]; then
        echo "[]"
    else
        echo "$result" | jq -e '. // [] | [.[] | {
            distribution_id: .[0],
            domain_name: .[1],
            status: .[2],
            enabled: .[3],
            comment: (.[4] // "N/A")
        }]' || echo "[]"
    fi
}

# Discover ECR repositories in a region
discover_ecr_repositories() {
    local region=$1
    log_debug "Discovering ECR repositories in $region..."

    aws ecr describe-repositories \
        --region "$region" \
        --query 'repositories[].[repositoryName,repositoryUri,createdAt,imageTagMutability,repositoryArn]' \
        --output json 2>/dev/null | jq '[.[] | {
            repository_name: .[0],
            repository_uri: .[1],
            created_at: .[2],
            tag_mutability: .[3],
            arn: .[4]
        }]' || echo "[]"
}

# Discover Cognito User Pools in a region
discover_cognito_user_pools() {
    local region=$1
    log_debug "Discovering Cognito User Pools in $region..."

    aws cognito-idp list-user-pools \
        --region "$region" \
        --max-results 60 \
        --query 'UserPools[].[Id,Name,CreationDate,LastModifiedDate]' \
        --output json 2>/dev/null | jq '[.[] | {
            pool_id: .[0],
            pool_name: .[1],
            created_at: .[2],
            last_modified: .[3]
        }]' || echo "[]"
}

# Discover Route53 Hosted Zones (global service)
discover_route53_zones() {
    log_debug "Discovering Route53 Hosted Zones..."

    aws route53 list-hosted-zones \
        --query 'HostedZones[].[Id,Name,Config.PrivateZone,ResourceRecordSetCount]' \
        --output json 2>/dev/null | jq '[.[] | {
            zone_id: (.[0] | split("/") | .[-1]),
            domain_name: .[1],
            is_private: .[2],
            record_count: .[3]
        }]' || echo "[]"
}

# Discover IAM Roles (global service)
discover_iam_roles() {
    log_debug "Discovering IAM Roles..."

    aws iam list-roles \
        --query 'Roles[].[RoleName,CreateDate,Arn,Description]' \
        --output json 2>/dev/null | jq '[.[] | {
            role_name: .[0],
            created_at: .[1],
            arn: .[2],
            description: (.[3] // "N/A")
        }] | .[0:100]' || echo "[]"  # Limit to first 100 to avoid huge output
}

# Discover Secrets Manager secrets in a region
discover_secrets() {
    local region=$1
    log_debug "Discovering Secrets Manager secrets in $region..."

    aws secretsmanager list-secrets \
        --region "$region" \
        --query 'SecretList[].[Name,ARN,CreatedDate,LastAccessedDate]' \
        --output json 2>/dev/null | jq '[.[] | {
            secret_name: .[0],
            arn: .[1],
            created_at: .[2],
            last_accessed: (.[3] // "N/A")
        }]' || echo "[]"
}

# Discover CloudWatch Log Groups in a region
discover_cloudwatch_log_groups() {
    local region=$1
    log_debug "Discovering CloudWatch Log Groups in $region..."

    aws logs describe-log-groups \
        --region "$region" \
        --query 'logGroups[].[logGroupName,creationTime,storedBytes,retentionInDays]' \
        --output json 2>/dev/null | jq '[.[] | {
            log_group_name: .[0],
            created_at: .[1],
            stored_bytes: .[2],
            retention_days: (.[3] // null)
        }] | .[0:100]' || echo "[]"  # Limit to first 100
}

# Discover SNS topics in a region
discover_sns_topics() {
    local region=$1
    log_debug "Discovering SNS topics in $region..."

    aws sns list-topics \
        --region "$region" \
        --query 'Topics[].[TopicArn]' \
        --output json 2>/dev/null | jq '[.[] | {
            topic_arn: .[0],
            topic_name: (.[0] | split(":") | .[-1])
        }]' || echo "[]"
}

# Discover SQS queues in a region
discover_sqs_queues() {
    local region=$1
    log_debug "Discovering SQS queues in $region..."

    aws sqs list-queues \
        --region "$region" \
        --query 'QueueUrls[]' \
        --output json 2>/dev/null | jq '[.[] | {
            queue_url: .,
            queue_name: (. | split("/") | .[-1])
        }]' || echo "[]"
}

# Discover KMS keys in a region
discover_kms_keys() {
    local region=$1
    log_debug "Discovering KMS keys in $region..."

    aws kms list-keys \
        --region "$region" \
        --query 'Keys[].[KeyId]' \
        --output json 2>/dev/null | jq -r '.[] | .[0]' | while read -r key_id; do
        aws kms describe-key \
            --region "$region" \
            --key-id "$key_id" \
            --query 'KeyMetadata.[KeyId,Arn,CreationDate,Enabled,KeyState,KeyManager]' \
            --output json 2>/dev/null || echo "[]"
    done | jq -s '[.[] | {
        key_id: .[0],
        arn: .[1],
        created_at: .[2],
        enabled: .[3],
        state: .[4],
        manager: .[5]
    }] | .[0:50]' || echo "[]"  # Limit to first 50
}

# Discover EventBridge rules in a region
discover_eventbridge_rules() {
    local region=$1
    log_debug "Discovering EventBridge rules in $region..."

    aws events list-rules \
        --region "$region" \
        --query 'Rules[].[Name,State,Description,ScheduleExpression,EventBusName,Arn]' \
        --output json 2>/dev/null | jq '[.[] | {
            rule_name: .[0],
            state: .[1],
            description: (.[2] // "N/A"),
            schedule: (.[3] // "N/A"),
            event_bus: .[4],
            arn: .[5]
        }]' || echo "[]"
}

# Discover Amplify apps in a region
discover_amplify_apps() {
    local region=$1
    log_debug "Discovering Amplify apps in $region..."

    # Skip if exclusion is enabled
    if [[ "$EXCLUDE_AMPLIFY" == "true" ]]; then
        log_debug "Skipping Amplify discovery (exclusion enabled)"
        echo "[]"
        return
    fi

    aws amplify list-apps \
        --region "$region" \
        --query 'apps[].[appId,name,defaultDomain,repository,platform,createTime,updateTime,appArn]' \
        --output json 2>/dev/null | jq '[.[] | {
            app_id: .[0],
            name: .[1],
            default_domain: .[2],
            repository: .[3],
            platform: .[4],
            created_at: .[5],
            updated_at: .[6],
            arn: .[7]
        }]' || echo "[]"
}

# Scan a single region for an account
scan_region() {
    local account_id=$1
    local region=$2

    log_info "Scanning region $region for account $account_id..."

    local region_data
    region_data=$(cat <<EOF
{
    "region": "$region",
    "services": {
        "compute": {
            "ec2_instances": $(discover_ec2_instances "$region"),
            "ecs_clusters": $(discover_ecs_clusters "$region"),
            "ecs_services": $(discover_ecs_services "$region"),
            "lambda_functions": $(discover_lambda_functions "$region")
        },
        "storage": {
            "s3_buckets": $(discover_s3_buckets "$region"),
            "ebs_volumes": [],
            "efs_filesystems": []
        },
        "database": {
            "dynamodb_tables": $(discover_dynamodb_tables "$region"),
            "rds_instances": $(discover_rds_instances "$region"),
            "rds_clusters": []
        },
        "networking": {
            "vpcs": $(discover_vpcs "$region"),
            "subnets": [],
            "security_groups": [],
            "load_balancers": $(discover_load_balancers "$region"),
            "api_gateways": $(discover_api_gateways "$region"),
            "cloudfront_distributions": []
        },
        "containers": {
            "ecr_repositories": $(discover_ecr_repositories "$region")
        },
        "security": {
            "iam_roles": [],
            "iam_policies": [],
            "secrets": $(discover_secrets "$region"),
            "kms_keys": $(discover_kms_keys "$region")
        },
        "dns": {
            "route53_zones": [],
            "route53_records": []
        },
        "auth": {
            "cognito_user_pools": $(discover_cognito_user_pools "$region"),
            "cognito_identity_pools": []
        },
        "monitoring": {
            "cloudwatch_alarms": [],
            "cloudwatch_log_groups": $(discover_cloudwatch_log_groups "$region"),
            "eventbridge_rules": $(discover_eventbridge_rules "$region")
        },
        "messaging": {
            "sns_topics": $(discover_sns_topics "$region"),
            "sqs_queues": $(discover_sqs_queues "$region")
        },
        "frontend": {
            "amplify_apps": $(discover_amplify_apps "$region")
        }
    }
}
EOF
)

    echo "$region_data"
}

# Scan global services (only once, not per region)
scan_global_services() {
    log_info "Scanning global services..."

    local global_data
    global_data=$(cat <<EOF
{
    "region": "global",
    "services": {
        "compute": {
            "ec2_instances": [],
            "ecs_clusters": [],
            "ecs_services": [],
            "lambda_functions": []
        },
        "storage": {
            "s3_buckets": [],
            "ebs_volumes": [],
            "efs_filesystems": []
        },
        "database": {
            "dynamodb_tables": [],
            "rds_instances": [],
            "rds_clusters": []
        },
        "networking": {
            "vpcs": [],
            "subnets": [],
            "security_groups": [],
            "load_balancers": [],
            "api_gateways": [],
            "cloudfront_distributions": $(discover_cloudfront_distributions)
        },
        "containers": {
            "ecr_repositories": []
        },
        "security": {
            "iam_roles": $(discover_iam_roles),
            "iam_policies": [],
            "secrets": [],
            "kms_keys": []
        },
        "dns": {
            "route53_zones": $(discover_route53_zones),
            "route53_records": []
        },
        "auth": {
            "cognito_user_pools": [],
            "cognito_identity_pools": []
        },
        "monitoring": {
            "cloudwatch_alarms": [],
            "cloudwatch_log_groups": []
        },
        "messaging": {
            "sns_topics": [],
            "sqs_queues": []
        }
    }
}
EOF
)

    echo "$global_data"
}

# Scan a single account
scan_account() {
    local account_id=$1
    local account_name=$2

    log_info "===== Scanning Account: $account_name ($account_id) ====="

    # Parse regions
    IFS=',' read -ra REGIONS <<< "$DEFAULT_REGIONS"

    local regions_data="[]"

    # Scan each region
    for region in "${REGIONS[@]}"; do
        local region_data
        region_data=$(scan_region "$account_id" "$region")
        regions_data=$(jq -s '.[0] + [.[1]]' <(echo "$regions_data") <(echo "$region_data"))
    done

    # Add global services if enabled
    if [[ "$INCLUDE_GLOBAL" == "true" ]]; then
        local global_data
        global_data=$(scan_global_services)
        regions_data=$(jq -s '.[0] + [.[1]]' <(echo "$regions_data") <(echo "$global_data"))
    fi

    # Build account object (use temp file to avoid argument list too long)
    local account_data
    local temp_regions_file="/tmp/aws_discovery_regions_$$.json"
    echo "$regions_data" > "$temp_regions_file"

    account_data=$(jq -n \
        --arg account_id "$account_id" \
        --arg account_name "$account_name" \
        --slurpfile regions "$temp_regions_file" \
        '{
            account_id: $account_id,
            account_name: $account_name,
            regions: $regions[0]
        }')

    rm -f "$temp_regions_file"
    echo "$account_data"
}

# Calculate summary statistics
calculate_summary() {
    local inventory=$1

    log_info "Calculating summary statistics..."

    # This is a placeholder - you would implement actual counting logic
    local summary
    summary=$(echo "$inventory" | jq '{
        total_resources: 0,
        resources_by_service: {},
        resources_by_region: {},
        resources_by_account: {},
        estimated_monthly_cost: null
    }')

    echo "$summary"
}

# Main discovery function
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
    log_info "========================================"

    # Get organization info
    get_organization_info

    # Get accounts
    local accounts_json
    accounts_json=$(get_accounts)

    local account_count
    account_count=$(echo "$accounts_json" | jq 'length')
    log_info "Found $account_count account(s) to scan"

    # Scan accounts
    local all_accounts="[]"
    echo "$accounts_json" | jq -c '.[]' | while read -r account; do
        local account_id
        local account_name
        account_id=$(echo "$account" | jq -r '.Id')
        account_name=$(echo "$account" | jq -r '.Name')

        local account_data
        account_data=$(scan_account "$account_id" "$account_name")

        # Append to all_accounts
        all_accounts=$(jq -s '.[0] + [.[1]]' <(echo "$all_accounts") <(echo "$account_data"))
        echo "$all_accounts" > /tmp/aws_discovery_accounts.json
    done

    # Read final accounts data
    all_accounts=$(cat /tmp/aws_discovery_accounts.json 2>/dev/null || echo "[]")

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
        --argjson accounts "$accounts_json" \
        '{
            generated_at: $timestamp,
            organization_id: $org_id,
            master_account_id: $master_account,
            regions_scanned: ($regions | split(",")),
            accounts_scanned: $accounts,
            version: $version,
            scan_duration_seconds: ($duration | tonumber)
        }')

    # Calculate summary (placeholder)
    local summary
    summary='{
        "total_resources": 0,
        "resources_by_service": {},
        "resources_by_region": {},
        "resources_by_account": {},
        "estimated_monthly_cost": null
    }'

    # Build final inventory (use temp files to avoid argument list too long)
    local metadata_file="/tmp/aws_discovery_metadata_$$.json"
    local summary_file="/tmp/aws_discovery_summary_$$.json"

    echo "$metadata" > "$metadata_file"
    echo "$summary" > "$summary_file"

    local inventory
    inventory=$(jq -n \
        --slurpfile metadata "$metadata_file" \
        --slurpfile summary "$summary_file" \
        --slurpfile accounts "/tmp/aws_discovery_accounts.json" \
        '{
            metadata: $metadata[0],
            summary: $summary[0],
            accounts: $accounts[0]
        }')

    # Write to output file
    echo "$inventory" | jq '.' > "$DEFAULT_OUTPUT"

    # Cleanup temp files
    rm -f "$metadata_file" "$summary_file"

    log_success "========================================"
    log_success "Discovery completed in ${duration} seconds"
    log_success "Inventory saved to: $DEFAULT_OUTPUT"
    log_success "========================================"

    # Cleanup temp files
    rm -f /tmp/aws_discovery_accounts.json
}

# Main execution
main() {
    parse_args "$@"
    check_prerequisites
    run_discovery
}

# Run main function
main "$@"
