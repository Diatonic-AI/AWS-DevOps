#!/usr/bin/env bash
set -euo pipefail

# Minimal Production Inventory Audit
# Objective: enumerate AWS resources and highlight items not tagged Environment=prod (or matching provided tag) 
# Scope: Amplify, Cognito, API Gateway (v1 & v2), Lambda, DynamoDB, S3, CloudFront, Secrets Manager, IAM Roles/Policies, Route53, EventBridge, CloudWatch Log Groups
# Requirements: aws cli v2, jq

TAG_KEY="Environment"
TAG_VALUE="prod"
REGION="${AWS_REGION:-us-east-2}"
PROFILE="${AWS_PROFILE:-default}"
OUT_DIR="aws-audit-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

log() { printf '\n[%s] %s\n' "$(date -Iseconds)" "$*"; }

check_dep() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
check_dep aws; check_dep jq

aws_cmd() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

save_json() { local file="$1"; shift; jq -S '.' >"$OUT_DIR/$file"; }

tag_filter_expr="select(.Tags // [] | any(.Key == \"$TAG_KEY\" and .Value == \"$TAG_VALUE\"))"

########################################
# Amplify Apps
########################################
audit_amplify() {
  log "Amplify apps"
  aws_cmd amplify list-apps --query 'apps' | jq 'map({appId,name,repository,platform,environmentVariables,Tags})' | save_json amplify-apps.json
  jq -r --arg k "$TAG_KEY" --arg v "$TAG_VALUE" '.[] | select(.Tags|type=="object") | select(.Tags[$k]==$v)|.appId' "$OUT_DIR/amplify-apps.json" > "$OUT_DIR/_amplify_prod_ids.txt" || true
}

########################################
# Cognito User Pools
########################################
audit_cognito() {
  log "Cognito user pools"
  aws_cmd cognito-idp list-user-pools --max-results 60 | jq -r '.UserPools[].Id' | while read -r pid; do
    aws_cmd cognito-idp describe-user-pool --user-pool-id "$pid" | jq '.UserPool' >> "$OUT_DIR/cognito-user-pools.raw.json"
  done
  jq -s '.' "$OUT_DIR/cognito-user-pools.raw.json" | save_json cognito-user-pools.json
}

########################################
# API Gateway (REST & HTTP)
########################################
audit_apigw() {
  log "API Gateway (REST v1)"; aws_cmd apigateway get-rest-apis | jq '.items[] | {id,name,createdDate}' | jq -s '.' | save_json apigw-rest.json
  log "API Gateway (HTTP v2)"; aws_cmd apigatewayv2 get-apis | jq '.Items[] | {ApiId,Name,ProtocolType}' | jq -s '.' | save_json apigw-http.json
}

########################################
# Lambda Functions
########################################
audit_lambda() {
  log "Lambda functions"
  aws_cmd lambda list-functions --max-items 1000 | jq '.Functions[] | {FunctionName,Runtime,LastModified,MemorySize,Timeout,Role,Environment,PackageType,Tags}' | jq -s '.' | save_json lambda-functions.json
  jq -r --arg k "$TAG_KEY" --arg v "$TAG_VALUE" '.[] | select(.Tags[$k]==$v)|.FunctionName' "$OUT_DIR/lambda-functions.json" > "$OUT_DIR/_lambda_prod_names.txt" || true
}

########################################
# DynamoDB Tables
########################################
audit_dynamodb() {
  log "DynamoDB tables"
  aws_cmd dynamodb list-tables --query 'TableNames[]' --output text | tr '\t' '\n' | while read -r tbl; do
    aws_cmd dynamodb describe-table --table-name "$tbl" | jq '.Table | {TableName,ItemCount,TableSizeBytes,TableArn}' >> "$OUT_DIR/dynamodb-tables.raw.json"
    aws_cmd dynamodb list-tags-of-resource --resource-arn "$(aws_cmd dynamodb describe-table --table-name "$tbl" --query 'Table.TableArn' --output text)" | jq --arg t "$tbl" '{Table:$t,Tags:.Tags}' >> "$OUT_DIR/dynamodb-table-tags.raw.json"
  done
  jq -s '.' "$OUT_DIR/dynamodb-tables.raw.json" | save_json dynamodb-tables.json
  jq -s '.' "$OUT_DIR/dynamodb-table-tags.raw.json" | save_json dynamodb-table-tags.json
}

########################################
# S3 Buckets (filter by region)
########################################
audit_s3() {
  log "S3 buckets (region $REGION)"
  aws_cmd s3api list-buckets | jq -r '.Buckets[].Name' | while read -r b; do
    loc=$(aws_cmd s3api get-bucket-location --bucket "$b" --query 'LocationConstraint' --output text 2>/dev/null || true)
    [[ "$loc" == "None" ]] && loc="us-east-1"
    if [[ "$loc" == "$REGION" ]]; then
      ver=$(aws_cmd s3api get-bucket-versioning --bucket "$b" 2>/dev/null | jq -r '.Status // "Disabled"')
      enc=$(aws_cmd s3api get-bucket-encryption --bucket "$b" 2>/dev/null | jq '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' || echo 'null')
      tags=$(aws_cmd s3api get-bucket-tagging --bucket "$b" 2>/dev/null | jq '.TagSet' || echo '[]')
      jq -n --arg name "$b" --arg loc "$loc" --arg ver "$ver" --argjson enc "$enc" --argjson tags "$tags" '{Name:$name,Region:$loc,Versioning:$ver,Encryption:$enc,Tags:$tags}' >> "$OUT_DIR/s3-buckets.raw.json"
    fi
  done
  jq -s '.' "$OUT_DIR/s3-buckets.raw.json" | save_json s3-buckets.json || echo '[]' > "$OUT_DIR/s3-buckets.json"
}

########################################
# CloudFront Distributions
########################################
audit_cloudfront() {
  log "CloudFront distributions"
  aws_cmd cloudfront list-distributions | jq '.DistributionList.Items[]? | {Id,DomainName,Comment,Enabled,Origins}' | jq -s '.' | save_json cloudfront-distributions.json || true
}

########################################
# Secrets Manager
########################################
audit_secrets() {
  log "Secrets Manager"
  aws_cmd secretsmanager list-secrets --max-results 100 | jq '.SecretList[] | {Name,ARN:ARN,Tags}' | jq -s '.' | save_json secrets.json
}

########################################
# IAM Roles (filter by prefix heuristics)
########################################
audit_iam() {
  log "IAM roles"
  aws_cmd iam list-roles | jq '.Roles[] | {RoleName,CreateDate,Arn,Tags}' | jq -s '.' | save_json iam-roles.json
}

########################################
# Route53 Hosted Zones & Records
########################################
audit_route53() {
  log "Route53"
  aws_cmd route53 list-hosted-zones | jq '.HostedZones[] | {Id,Name,PrivateZone}' | jq -s '.' | save_json route53-zones.json
}

########################################
# CloudWatch Log Groups (size & retention)
########################################
audit_logs() {
  log "CloudWatch log groups"
  aws_cmd logs describe-log-groups --limit 500 | jq '.logGroups[] | {logGroupName,storedBytes,retentionInDays}' | jq -s '.' | save_json log-groups.json
}

########################################
# EventBridge Buses (for possible pruning)
########################################
audit_eventbridge() {
  log "EventBridge event buses"
  aws_cmd events list-event-buses | jq '.EventBuses[] | {Name,Arn}' | jq -s '.' | save_json event-buses.json
}

########################################
# Summaries
########################################
summarize() {
  log "Produce summary tables"
  {
    echo "Category,Count";
    for f in amplify-apps cognito-user-pools apigw-rest apigw-http lambda-functions dynamodb-tables s3-buckets cloudfront-distributions secrets iam-roles route53-zones log-groups event-buses; do
      c=$(jq 'length' "$OUT_DIR/$f.json" 2>/dev/null || echo 0); echo "$f,$c"; done
  } > "$OUT_DIR/summary.csv"
  log "Summary written to $OUT_DIR/summary.csv"
}

main() {
  log "Starting minimal production audit (region=$REGION profile=$PROFILE)"
  audit_amplify
  audit_cognito
  audit_apigw
  audit_lambda
  audit_dynamodb
  audit_s3
  audit_cloudfront
  audit_secrets
  audit_iam
  audit_route53
  audit_logs
  audit_eventbridge
  summarize
  log "Done. Review JSON in $OUT_DIR."
  cat <<NOTE
Next Steps:
1. Identify resources NOT tagged $TAG_KEY=$TAG_VALUE that relate to dev/staging.
2. For each candidate, verify no production traffic (check CloudWatch logs / metrics last 7d).
3. Plan deletions: create a change set file listing aws cli delete commands.
4. BEFORE deleting state-managed (Terraform) resources, remove them from Terraform code OR 'terraform state rm' then delete with CLI.
5. Import any unmanaged but required prod resources into Terraform (terraform import ...) to achieve full IaC parity.
6. Commit a pruned Terraform configuration (modules only for production) and run 'terraform plan' expecting ZERO creates for existing infra.
NOTE
}

main "$@"
