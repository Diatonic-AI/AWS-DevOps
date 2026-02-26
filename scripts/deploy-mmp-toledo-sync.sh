#!/bin/bash
# ============================================================================
# MMP Toledo DynamoDB to Supabase Sync - Deployment Script
# ============================================================================
#
# This script provides a complete deployment workflow with:
# - State management (local or S3 backend)
# - Plan validation and saving
# - Cost estimation before apply
# - Rollback capabilities
# - DynamoDB stream enablement
#
# Usage:
#   ./scripts/deploy-mmp-toledo-sync.sh [command] [options]
#
# Commands:
#   init       - Initialize Terraform and download providers
#   validate   - Validate configuration syntax
#   plan       - Generate and save execution plan
#   apply      - Apply the saved plan
#   destroy    - Destroy all resources
#   enable-streams - Enable DynamoDB streams on existing tables
#   status     - Show current deployment status
#   logs       - Tail CloudWatch logs
#
# Options:
#   --env      - Environment (dev, staging, prod) [default: dev]
#   --auto-approve - Skip confirmation prompts
#   --backend  - Use S3 backend instead of local state
#
# Examples:
#   ./scripts/deploy-mmp-toledo-sync.sh init
#   ./scripts/deploy-mmp-toledo-sync.sh plan --env=dev
#   ./scripts/deploy-mmp-toledo-sync.sh apply --auto-approve
#   ./scripts/deploy-mmp-toledo-sync.sh enable-streams
#
# ============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/infrastructure/terraform/mmp-toledo-sync"
PLANS_DIR="$TF_DIR/plans"
LOGS_DIR="$TF_DIR/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
ENVIRONMENT="dev"
AUTO_APPROVE=""
USE_S3_BACKEND=false

# Parse command line arguments
COMMAND="${1:-help}"
shift || true

while [[ $# -gt 0 ]]; do
    case $1 in
        --env=*)
            ENVIRONMENT="${1#*=}"
            ;;
        --auto-approve)
            AUTO_APPROVE="-auto-approve"
            ;;
        --backend)
            USE_S3_BACKEND=true
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
    shift
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod.${NC}"
    exit 1
fi

# Create directories
mkdir -p "$PLANS_DIR" "$LOGS_DIR"

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform >= 1.5.0"
        exit 1
    fi

    TF_VERSION=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $TF_VERSION"

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed."
        exit 1
    fi

    # Verify AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid."
        exit 1
    fi

    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    log_info "AWS Account: $AWS_ACCOUNT"

    log_success "All prerequisites met."
}

check_env_vars() {
    log_info "Checking required environment variables..."

    # Check if tfvars exists
    if [[ ! -f "$TF_DIR/terraform.tfvars" ]]; then
        if [[ -f "$TF_DIR/terraform.tfvars.example" ]]; then
            log_warn "terraform.tfvars not found. Copying from example..."
            cp "$TF_DIR/terraform.tfvars.example" "$TF_DIR/terraform.tfvars"
            log_warn "Please edit terraform.tfvars with your Supabase credentials!"
        else
            log_error "No terraform.tfvars or terraform.tfvars.example found!"
            exit 1
        fi
    fi

    # Check for sensitive variables via environment
    if [[ -z "${TF_VAR_supabase_anon_key:-}" ]]; then
        log_warn "TF_VAR_supabase_anon_key not set. Using value from terraform.tfvars"
    fi

    log_success "Environment variables checked."
}

# ============================================================================
# Terraform Commands
# ============================================================================

cmd_init() {
    log_info "Initializing Terraform..."
    cd "$TF_DIR"

    # Configure backend
    if $USE_S3_BACKEND; then
        log_info "Using S3 backend for state management"
        # Enable S3 backend in main.tf (uncomment backend block)
        sed -i 's/# backend "s3"/backend "s3"/' main.tf
        sed -i 's/#   bucket/  bucket/' main.tf
        sed -i 's/#   key/  key/' main.tf
        sed -i 's/#   region/  region/' main.tf
        sed -i 's/#   dynamodb_table/  dynamodb_table/' main.tf
        sed -i 's/#   encrypt/  encrypt/' main.tf
        sed -i 's/# }/}/' main.tf
    fi

    terraform init -upgrade \
        -reconfigure \
        2>&1 | tee "$LOGS_DIR/init-$(date +%Y%m%d-%H%M%S).log"

    log_success "Terraform initialized successfully."
}

cmd_validate() {
    log_info "Validating Terraform configuration..."
    cd "$TF_DIR"

    # Format check
    if ! terraform fmt -check -recursive; then
        log_warn "Some files are not properly formatted. Running terraform fmt..."
        terraform fmt -recursive
    fi

    # Validate syntax
    terraform validate

    log_success "Configuration is valid."
}

cmd_plan() {
    log_info "Generating Terraform plan for environment: $ENVIRONMENT"
    cd "$TF_DIR"

    PLAN_FILE="$PLANS_DIR/tfplan-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S).plan"
    PLAN_JSON="$PLANS_DIR/tfplan-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S).json"

    # Generate plan
    terraform plan \
        -var="environment=$ENVIRONMENT" \
        -out="$PLAN_FILE" \
        -detailed-exitcode \
        2>&1 | tee "$LOGS_DIR/plan-$(date +%Y%m%d-%H%M%S).log" || true

    # Save plan as JSON for analysis
    terraform show -json "$PLAN_FILE" > "$PLAN_JSON"

    # Show cost estimate (simplified)
    echo ""
    echo "============================================================================"
    echo "COST ESTIMATE (Monthly)"
    echo "============================================================================"
    echo ""
    echo "  Lambda (ARM64, 128MB):     \$0.00 (within free tier for low volume)"
    echo "  DynamoDB Streams:          \$0.00 (included with DynamoDB)"
    echo "  Secrets Manager:           \$0.40 (1 secret)"
    echo "  CloudWatch Logs:           \$0.00-\$0.50 (depends on volume)"
    echo "  SQS Dead Letter Queue:     \$0.00 (within free tier)"
    echo "  ─────────────────────────────────────────────────────────────────────"
    echo "  TOTAL ESTIMATED:           \$0.40-\$1.00/month"
    echo ""
    echo "============================================================================"

    log_success "Plan saved to: $PLAN_FILE"
    echo ""
    echo "To apply this plan, run:"
    echo "  ./scripts/deploy-mmp-toledo-sync.sh apply --env=$ENVIRONMENT"

    # Symlink latest plan
    ln -sf "$PLAN_FILE" "$PLANS_DIR/latest-$ENVIRONMENT.plan"
}

cmd_apply() {
    log_info "Applying Terraform plan for environment: $ENVIRONMENT"
    cd "$TF_DIR"

    PLAN_FILE="$PLANS_DIR/latest-$ENVIRONMENT.plan"

    if [[ ! -f "$PLAN_FILE" ]]; then
        log_warn "No saved plan found. Generating new plan..."
        cmd_plan
        PLAN_FILE="$PLANS_DIR/latest-$ENVIRONMENT.plan"
    fi

    if [[ -z "$AUTO_APPROVE" ]]; then
        echo ""
        read -p "Do you want to apply this plan? (yes/no): " CONFIRM
        if [[ "$CONFIRM" != "yes" ]]; then
            log_warn "Apply cancelled."
            exit 0
        fi
    fi

    terraform apply $AUTO_APPROVE "$PLAN_FILE" \
        2>&1 | tee "$LOGS_DIR/apply-$(date +%Y%m%d-%H%M%S).log"

    log_success "Deployment completed successfully!"

    # Show outputs
    echo ""
    echo "============================================================================"
    echo "DEPLOYMENT OUTPUTS"
    echo "============================================================================"
    terraform output
}

cmd_destroy() {
    log_info "Destroying resources for environment: $ENVIRONMENT"
    cd "$TF_DIR"

    if [[ -z "$AUTO_APPROVE" ]]; then
        echo ""
        log_warn "This will DESTROY all MMP Toledo sync resources!"
        read -p "Are you sure? Type 'destroy' to confirm: " CONFIRM
        if [[ "$CONFIRM" != "destroy" ]]; then
            log_warn "Destroy cancelled."
            exit 0
        fi
    fi

    terraform destroy \
        -var="environment=$ENVIRONMENT" \
        $AUTO_APPROVE \
        2>&1 | tee "$LOGS_DIR/destroy-$(date +%Y%m%d-%H%M%S).log"

    log_success "Resources destroyed."
}

cmd_enable_streams() {
    log_info "Enabling DynamoDB Streams on MMP Toledo tables..."

    TABLES=(
        "mmp-toledo-leads-prod"
        "mmp-toledo-otp-prod"
    )

    for TABLE in "${TABLES[@]}"; do
        log_info "Enabling stream on table: $TABLE"

        # Check if table exists
        if aws dynamodb describe-table --table-name "$TABLE" &> /dev/null; then
            # Enable stream
            aws dynamodb update-table \
                --table-name "$TABLE" \
                --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES \
                --output json || {
                log_warn "Stream may already be enabled on $TABLE"
            }
            log_success "Stream enabled on $TABLE"
        else
            log_warn "Table $TABLE does not exist. Skipping..."
        fi
    done

    log_success "DynamoDB streams configuration complete."
}

cmd_status() {
    log_info "Checking deployment status..."
    cd "$TF_DIR"

    echo ""
    echo "============================================================================"
    echo "TERRAFORM STATE"
    echo "============================================================================"

    if [[ -f "$TF_DIR/terraform.tfstate" ]] || $USE_S3_BACKEND; then
        terraform show -no-color 2>/dev/null | head -50 || echo "No state found"
    else
        echo "No local state file found."
    fi

    echo ""
    echo "============================================================================"
    echo "LAMBDA FUNCTION STATUS"
    echo "============================================================================"

    FUNCTION_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "")
    if [[ -n "$FUNCTION_NAME" ]]; then
        aws lambda get-function --function-name "$FUNCTION_NAME" \
            --query '{Name: Configuration.FunctionName, State: Configuration.State, Runtime: Configuration.Runtime, Memory: Configuration.MemorySize, Timeout: Configuration.Timeout}' \
            --output table 2>/dev/null || echo "Lambda function not found"
    else
        echo "Lambda function not deployed yet."
    fi

    echo ""
    echo "============================================================================"
    echo "DLQ STATUS"
    echo "============================================================================"

    DLQ_URL=$(terraform output -raw dlq_url 2>/dev/null || echo "")
    if [[ -n "$DLQ_URL" ]]; then
        aws sqs get-queue-attributes \
            --queue-url "$DLQ_URL" \
            --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
            --output table 2>/dev/null || echo "DLQ not found"
    else
        echo "DLQ not deployed yet."
    fi
}

cmd_logs() {
    log_info "Tailing CloudWatch logs..."
    cd "$TF_DIR"

    LOG_GROUP=$(terraform output -raw cloudwatch_log_group 2>/dev/null || echo "")
    if [[ -z "$LOG_GROUP" ]]; then
        log_error "Log group not found. Is the Lambda deployed?"
        exit 1
    fi

    aws logs tail "$LOG_GROUP" --follow
}

cmd_help() {
    cat << EOF
MMP Toledo DynamoDB to Supabase Sync - Deployment Script

Usage: ./scripts/deploy-mmp-toledo-sync.sh [command] [options]

Commands:
  init           Initialize Terraform and download providers
  validate       Validate configuration syntax
  plan           Generate and save execution plan
  apply          Apply the saved plan
  destroy        Destroy all resources
  enable-streams Enable DynamoDB streams on existing tables
  status         Show current deployment status
  logs           Tail CloudWatch logs
  help           Show this help message

Options:
  --env=<env>     Environment (dev, staging, prod) [default: dev]
  --auto-approve  Skip confirmation prompts
  --backend       Use S3 backend instead of local state

Examples:
  # Initialize and deploy to dev
  ./scripts/deploy-mmp-toledo-sync.sh init
  ./scripts/deploy-mmp-toledo-sync.sh plan --env=dev
  ./scripts/deploy-mmp-toledo-sync.sh apply

  # Deploy to production with S3 backend
  ./scripts/deploy-mmp-toledo-sync.sh init --backend
  ./scripts/deploy-mmp-toledo-sync.sh plan --env=prod
  ./scripts/deploy-mmp-toledo-sync.sh apply --env=prod

  # Enable DynamoDB streams
  ./scripts/deploy-mmp-toledo-sync.sh enable-streams

  # View logs
  ./scripts/deploy-mmp-toledo-sync.sh logs

Cost Estimate:
  ~\$0.40-\$1.00/month (most components within AWS Free Tier)

EOF
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "============================================================================"
    echo "MMP Toledo DynamoDB to Supabase Sync Deployment"
    echo "============================================================================"
    echo "Environment: $ENVIRONMENT"
    echo "Command: $COMMAND"
    echo "============================================================================"
    echo ""

    case "$COMMAND" in
        init)
            check_prerequisites
            check_env_vars
            cmd_init
            ;;
        validate)
            cmd_validate
            ;;
        plan)
            check_prerequisites
            check_env_vars
            cmd_validate
            cmd_plan
            ;;
        apply)
            check_prerequisites
            cmd_apply
            ;;
        destroy)
            check_prerequisites
            cmd_destroy
            ;;
        enable-streams)
            check_prerequisites
            cmd_enable_streams
            ;;
        status)
            cmd_status
            ;;
        logs)
            cmd_logs
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            cmd_help
            exit 1
            ;;
    esac
}

main
