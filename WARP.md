# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

**Generated:** 2025-09-07 17:15 UTC  
**Location:** `/home/daclab-ai/dev/AWS-DevOps`  
**Host:** daclab-ai | **User:** daclab-ai  
**Project Type:** AWS Infrastructure as Code (Terraform + GitHub Actions)

---

## 📍 Project Overview

This repository manages **AWS DevOps Infrastructure & Applications** using Infrastructure as Code (IaC) principles with a focus on staying within AWS Free Tier limits. The project provides comprehensive Terraform modules, CI/CD automation, cost monitoring, and multi-environment deployment patterns for AWS workloads.

**Core Capabilities:**
- Terraform-based infrastructure management with reusable modules
- Multi-tier VPC architecture with cost-optimized configurations
- Automated CI/CD pipelines via GitHub Actions
- Free Tier monitoring and cost optimization
- Security and compliance best practices
- Comprehensive documentation and operational runbooks

**Primary Technology Stack:**
- **Infrastructure:** Terraform 1.5+, AWS Provider 5.0+
- **CI/CD:** GitHub Actions with automated plan/apply workflows
- **Monitoring:** CloudWatch, custom free-tier usage scripts
- **Security:** AWS security services (GuardDuty, Config, CloudTrail)

**Key Links:**
- [README.md](./README.md) - Comprehensive project documentation
- [Free Tier Guide](./docs/Free-Tier.md) - Complete AWS Free Tier reference
- [Workflow Setup](./github/WORKFLOW_SETUP_GUIDE.md) - CI/CD automation guide

---

## 🛡️ Safety Rules and Do-Not-Touch Areas

### WARP Safety Protocol
- **Always discover context first:** Run WARP.md discovery at task boundaries
- **Read-only by default:** Perform discovery and validation before making changes
- **Respect environment boundaries:** Understand dev/staging/prod implications
- **Secret hygiene:** Never commit credentials, API keys, or sensitive data

### Do-Not-Touch Critical Areas
- **`.github/workflows/`** - CI/CD pipeline definitions (requires approval)
- **`infrastructure/terraform/core/terraform.*.tfvars`** - Environment configurations
- **State management files** - Terraform backend and state configurations
- **Production resources** - Requires explicit approval for prod environment changes

### Change Control Requirements
- All infrastructure changes require Pull Requests
- Production deployments require manual approval
- Security scanning (tfsec) must pass
- Cost estimation review for new resources

---

## 🏗️ Architecture and Environments

### Environment Strategy
- **`dev`** - Development environment with single NAT Gateway (cost optimization)
- **`staging`** - Pre-production testing with enhanced security
- **`prod`** - Production environment with full HA and monitoring

### Infrastructure Architecture
- **Multi-AZ VPC** - Three-tier subnet architecture (public, private, data)
- **Cost-Optimized Networking** - Environment-specific NAT Gateway configuration
- **Security First** - VPC Flow Logs, security groups, VPC endpoints
- **Free Tier Focused** - Resource configurations stay within AWS Free Tier limits

### Terraform Backend
- **S3 + DynamoDB** backend for state management
- **Environment isolation** via separate state files
- **Remote state sharing** for cross-stack references

### Resource Naming Convention
```
<project>-<environment>-<resource-type>-<unique-suffix>
aws-devops-dev-vpc-abc123
aws-devops-prod-cluster-xyz789
```

---

## 📁 Repository Structure and Directory Map

### Current Level (`.`)
**Path:** `/home/daclab-ai/dev/AWS-DevOps`  
**Purpose:** Project root directory  

### Directory Structure (±2 Levels)

- **`docs/`** - Documentation and architectural guides
  - Files: 5 | Purpose: Architecture, setup guides, Free Tier reference
- **`infrastructure/`** - Infrastructure as Code definitions
  - `terraform/` - Terraform configurations and modules
    - `core/` - Core infrastructure (VPC, security, web apps)
    - `modules/` - Reusable Terraform modules (VPC, ECS, CloudFront, etc.)
- **`scripts/`** - Automation and utility scripts
  - `monitoring/` - Free tier usage monitoring and cost alerts
- **`.github/`** - CI/CD pipeline definitions
  - `workflows/` - GitHub Actions for Terraform deployment and validation

### File Type Distribution
- **Terraform (`.tf`)**: 21 files - Infrastructure definitions
- **Markdown (`.md`)**: 15 files - Documentation and guides
- **Shell (`.sh`)**: 2 files - Deployment and monitoring automation
- **YAML (`.yml`)**: 3 files - GitHub Actions workflows

**Total Discovery:** 8 directories, 41 files analyzed

---

## 🔄 Toolchain and CI/CD Workflows

### GitHub Actions Pipeline Overview
1. **Terraform Validation (`terraform-validate.yml`)**
   - Triggers: Pull requests, feature branches
   - Validates: Format, syntax, security (tfsec), cost estimation
   
2. **Terraform Deployment (`terraform-deploy.yml`)**
   - Triggers: Push to main, manual dispatch
   - Environments: Dev (automatic), Staging/Prod (manual approval)
   - Features: Plan validation, artifact storage, deployment verification

### Terraform Workflow
```bash
# Standard workflow using deploy script
cd infrastructure/terraform
./deploy.sh <environment> <action>

# Examples:
./deploy.sh dev plan          # Generate and save plan
./deploy.sh dev apply         # Apply from saved plan
./deploy.sh dev plan-apply    # Plan and apply in one step
```

### Environment Promotion Strategy
- **Dev**: Automatic deployment on merge to main
- **Staging**: Manual approval required
- **Production**: Manual approval + additional reviewers

---

## 📋 Operations Runbooks and Common Tasks

### Terraform Operations

#### Initialization and Planning
```bash
# Initialize Terraform backend
cd infrastructure/terraform/core
terraform init

# Plan changes for specific environment
terraform plan -var-file="terraform.dev.tfvars" -out="dev-plan.tfplan"

# Apply saved plan
terraform apply "dev-plan.tfplan"
```

#### Using the Deployment Script (Recommended)
```bash
# Navigate to Terraform directory
cd infrastructure/terraform

# Development environment
./deploy.sh dev validate      # Validate configuration
./deploy.sh dev plan          # Create plan file
./deploy.sh dev apply         # Apply from plan file
./deploy.sh dev plan-apply    # Plan and apply in one step

# Production environment (requires approval)
./deploy.sh prod plan
./deploy.sh prod apply        # Requires confirmation
```

### Cost Monitoring and Free Tier Management
```bash
# Check current free tier usage
scripts/monitoring/free-tier-check.sh

# Monitor current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date -d 'next month' +%Y-%m-01) \
  --granularity DAILY --metrics BlendedCost

# List running EC2 instances (free tier: 750 hours/month)
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,InstanceType]' \
  --output table
```

### Resource Management
```bash
# Check VPC and networking
aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock,State]' --output table

# Monitor S3 usage (free tier: 5GB)
aws s3 ls --summarize --human-readable --recursive s3://your-bucket-name

# Check RDS instances (free tier: db.t2.micro, 750 hours/month)
aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]' \
  --output table
```

---

## 🔐 Secrets and Configuration Management

### AWS Credentials
- **Local Development**: Use AWS CLI profiles or SSO
- **CI/CD**: GitHub repository secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- **Never commit**: Credentials, API keys, or sensitive data to repository

### Environment Variables
```bash
# Required for Terraform
export AWS_REGION=us-east-2
export AWS_PROFILE=default  # or your profile name

# Optional for enhanced features
export TF_VAR_notification_email=your-email@domain.com
```

### Configuration Files
- **`terraform.dev.tfvars`** - Development environment variables
- **`terraform.staging.tfvars`** - Staging environment variables  
- **`terraform.prod.tfvars`** - Production environment variables

---

## 🚀 Onboarding and Local Setup

### Prerequisites
Install required tools for local development:

```bash
# Essential tools
aws --version          # AWS CLI v2+
terraform --version    # Terraform >= 1.5.0
git --version          # Git for version control
jq --version          # JSON processing

# Optional but recommended
bc --version          # Calculator for cost monitoring scripts
```

### Initial Setup Steps

1. **Configure AWS Credentials**
```bash
# Option 1: AWS Configure
aws configure

# Option 2: AWS SSO (recommended)
aws configure sso

# Verify credentials
aws sts get-caller-identity
```

2. **Set Default Region**
```bash
aws configure set default.region us-east-2
```

3. **Clone and Initialize Repository**
```bash
cd ~/dev/AWS-DevOps
terraform -chdir=infrastructure/terraform/core init
```

4. **First-Run Validation**
```bash
# Verify AWS access
aws sts get-caller-identity

# Validate Terraform configuration
cd infrastructure/terraform/core
terraform validate

# Check free tier usage
scripts/monitoring/free-tier-check.sh
```

---

## 🔍 Diagnostics and Troubleshooting

### Log Locations
- **GitHub Actions**: Repository Actions tab for CI/CD logs
- **CloudWatch**: AWS CloudWatch for infrastructure logs
- **Terraform**: Local plan/apply output and state files

### Common Issues and Solutions

#### AWS Authentication Errors
```bash
# Symptom: "could not retrieve caller identity"
# Solution: Verify AWS credentials
aws sts get-caller-identity
aws configure list
```

#### Terraform State Issues
```bash
# Symptom: "Failed to get existing workspaces"
# Solution: Check backend configuration and permissions
terraform init -reconfigure
```

#### Free Tier Exceeded Alerts
```bash
# Check current usage across services
scripts/monitoring/free-tier-check.sh

# Review detailed cost breakdown
aws ce get-cost-and-usage --time-period Start=$(date +%Y-%m-01),End=$(date -d 'next month' +%Y-%m-01) --granularity DAILY --metrics BlendedCost
```

### Health Check Commands
```bash
# Terraform configuration validation
terraform fmt -check=true -recursive
terraform validate

# AWS service connectivity
aws ec2 describe-regions --output table
aws s3 ls

# Infrastructure status
terraform show
terraform output
```

---

## 🛠️ MCP Tools and Productivity

### Recommended MCP Tools for AWS-DevOps

1. **`file-system-manager`** - Enhanced file operations and directory management
   - Usage: `mcp connect file-system-manager`
   - Benefits: Advanced file operations, directory analysis, content management

2. **`git-operations`** - Git repository operations and workflow automation
   - Usage: `mcp connect git-operations`
   - Benefits: Branch management, commit analysis, merge assistance

3. **`markdown-processor`** - Process and validate Markdown documentation
   - Usage: `mcp connect markdown-processor`
   - Benefits: Documentation quality, link validation, content enhancement

4. **`data-transformer`** - Transform and manipulate JSON/YAML configuration files
   - Usage: `mcp connect data-transformer`
   - Benefits: Terraform variable processing, configuration validation

### Quick MCP Integration Commands
```bash
# List all available tools
mcp list-tools

# Connect to primary tool for Infrastructure operations
mcp connect file-system-manager

# Chain multiple tools for complex operations
mcp tool-chain --tools="git-operations,file-system-manager" --sequence

# View specific tool documentation
mcp tool-info file-system-manager
```

### AWS CLI Integration (Non-MCP)
```bash
# AWS service discovery
aws ec2 describe-instances --output table
aws s3 ls
aws rds describe-db-instances --output table

# Cost monitoring
aws ce get-cost-and-usage --time-period Start=$(date +%Y-%m-01),End=$(date -d 'next month' +%Y-%m-01) --granularity MONTHLY --metrics BlendedCost
```

---

## 📊 Metadata and Working Logs

**WARP Version:** 2.0.0  
**Framework Compliance:** ✅ Universal Framework Compatible  
**Working Logs Directory:** `~/Documents/working-warp/AWS-DevOps__$(date +%Y%m%d-%H%M%S)/`

### Working Logs Usage
```bash
# Source helper functions
source ~/Documents/working-warp/AWS-DevOps__*/helpers.sh

# Add tasks to working log
add_task "Plan dev environment infrastructure changes"
add_task "Validate free tier usage after deployment"

# Mark tasks complete
complete_task "Infrastructure validation completed successfully"

# Add results and findings
add_result "VPC created with 3 AZs and cost-optimized NAT Gateway"
```

### Update Policy
**Update WARP.md when:**
- New environments or AWS accounts added
- Changes to Terraform backend configuration
- New CI/CD workflows or pipeline changes
- Major architectural changes (new services, significant refactoring)
- Tool or framework updates (Terraform version, AWS provider)

**Update Process:**
1. Run discovery scan: review repository changes
2. Update affected sections with current information
3. Update "Last Updated" timestamp
4. Create PR: `chore(docs): update WARP.md for <change>`

---

## 🎯 Next Steps and Immediate Actions

### For New Contributors
1. **Review Documentation**: Start with [README.md](./README.md) and [Free-Tier.md](./docs/Free-Tier.md)
2. **Complete Setup**: Follow onboarding steps above for AWS CLI and Terraform
3. **Validate Environment**: Run `scripts/monitoring/free-tier-check.sh`
4. **Understand Workflows**: Review [Workflow Setup Guide](./.github/WORKFLOW_SETUP_GUIDE.md)

### For Infrastructure Changes
1. **Plan First**: Always run `terraform plan` before applying changes
2. **Cost Review**: Estimate costs and validate Free Tier compliance
3. **Security Scan**: Ensure security checks pass in PR validation
4. **Environment Strategy**: Test in dev before promoting to staging/prod

### Immediate Verification Checklist
- [ ] AWS credentials configured and validated
- [ ] Terraform initialization successful
- [ ] Free tier usage within limits
- [ ] GitHub Actions workflows accessible
- [ ] MCP tools connected and operational

---

**Last Updated:** 2025-09-07 17:15 UTC  
**Updated By:** WARP Bootstrap System  
**Status:** ✅ Ready for AWS Infrastructure Operations

*This WARP.md file provides comprehensive guidance for working with AWS DevOps infrastructure. Keep it updated as the project evolves and always prioritize cost optimization and security best practices.*
