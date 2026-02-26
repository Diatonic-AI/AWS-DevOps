# 🚀 Unified Terraform Migration Guide

## Overview

This guide provides step-by-step instructions for migrating from the current fragmented Terraform configuration to the unified management system. This consolidation addresses the key issues identified:

- ✅ **Multiple separate state files** → Single unified state with workspace isolation
- ✅ **Duplicated configurations** → Centralized modules and shared resources  
- ✅ **Inconsistent variable naming** → Standardized variable structure
- ✅ **Inconsistent backend configurations** → Unified S3/DynamoDB backend
- ✅ **Resource naming conflicts** → Consistent naming with workspace prefixes

## 📋 Pre-Migration Checklist

### 1. Backup Current State
```bash
# Backup all existing state files
cd /home/daclab-ai/dev/AWS-DevOps

# Create backup directory
mkdir -p backups/pre-migration-$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="backups/pre-migration-$(date +%Y%m%d-%H%M%S)"

# Backup main infrastructure state
cp infrastructure/terraform/core/terraform.tfstate* $BACKUP_DIR/

# Backup AI Nexus states
cp apps/ai-nexus-workbench/infrastructure/terraform.tfstate* $BACKUP_DIR/ 2>/dev/null || true
cp apps/ai-nexus-workbench/infra/terraform.tfstate* $BACKUP_DIR/ 2>/dev/null || true

# Backup MinIO state
cp minio-infrastructure/terraform/terraform.tfstate* $BACKUP_DIR/ 2>/dev/null || true

echo "✅ Backups created in: $BACKUP_DIR"
```

### 2. Document Current Resources
```bash
# Document current resources for each deployment
cd infrastructure/terraform/core && terraform state list > ../../../$BACKUP_DIR/core_resources.txt
cd ../../../apps/ai-nexus-workbench/infrastructure && terraform state list > ../../../$BACKUP_DIR/ai_nexus_resources.txt
cd ../../../minio-infrastructure/terraform && terraform state list > ../../../$BACKUP_DIR/minio_resources.txt
```

### 3. Verify AWS Credentials and Permissions
```bash
# Verify AWS access
aws sts get-caller-identity
aws s3 ls  # Verify S3 permissions
aws dynamodb list-tables --region us-east-2 --max-items 5  # Verify DynamoDB permissions
```

## 🏗️ Migration Process

### Phase 1: Backend Setup (20 minutes)

#### Step 1.1: Initialize Backend Infrastructure
```bash
cd /home/daclab-ai/dev/AWS-DevOps/unified-terraform

# Initialize backend (creates S3 bucket and DynamoDB table)
./scripts/deploy.sh backend setup
```

#### Step 1.2: Verify Backend Creation
```bash
# Check that backend resources were created
aws s3 ls | grep terraform-state-unified
aws dynamodb list-tables --region us-east-2 | grep terraform-state-lock

# Note the bucket name from the output for next steps
```

### Phase 2: Initialize Unified Configuration (15 minutes)

#### Step 2.1: Initialize Terraform with New Backend
```bash
cd /home/daclab-ai/dev/AWS-DevOps/unified-terraform

# Initialize with the new backend
terraform init
```

#### Step 2.2: Create Workspaces
```bash
# Create all required workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
terraform workspace new ai-nexus
terraform workspace new minio

# Verify workspaces
terraform workspace list
```

### Phase 3: Import Existing Resources (45 minutes)

#### Step 3.1: Import Core Infrastructure (dev workspace)
```bash
# Switch to dev workspace
terraform workspace select dev

# Import VPC (replace with actual VPC ID from your infrastructure)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=aws-devops-dev-vpc" --query 'Vpcs[0].VpcId' --output text)
terraform import module.core_infrastructure[0].aws_vpc.main $VPC_ID

# Import Internet Gateway
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=aws-devops-dev-igw" --query 'InternetGateways[0].InternetGatewayId' --output text)
terraform import module.core_infrastructure[0].aws_internet_gateway.main $IGW_ID

# Import subnets (repeat for each subnet)
# Example for first public subnet:
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=aws-devops-dev-public-*" --query 'Subnets[0].SubnetId' --output text)
terraform import module.core_infrastructure[0].aws_subnet.public[0] $SUBNET_ID

# Continue importing other core resources...
# Note: This process may take time depending on the number of resources
```

#### Step 3.2: Import AI Nexus Resources (ai-nexus workspace)
```bash
# Switch to ai-nexus workspace
terraform workspace select ai-nexus

# Import Cognito User Pool
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 20 --query 'UserPools[?Name==`ai-nexus-users`].Id' --output text)
if [[ -n "$USER_POOL_ID" ]]; then
    terraform import module.ai_nexus_workbench[0].aws_cognito_user_pool.main $USER_POOL_ID
fi

# Import DynamoDB tables
for table in $(aws dynamodb list-tables --query 'TableNames[?contains(@,`ai-nexus`) || contains(@,`ainexus`)]' --output text); do
    terraform import module.ai_nexus_workbench[0].aws_dynamodb_table.main["$table"] $table
done

# Import Lambda functions
for func in $(aws lambda list-functions --query 'Functions[?contains(FunctionName,`ai-nexus`) || contains(FunctionName,`ainexus`)].FunctionName' --output text); do
    terraform import module.ai_nexus_workbench[0].aws_lambda_function.main["$func"] $func
done

# Continue with other AI Nexus resources...
```

#### Step 3.3: Import MinIO Resources (minio workspace)
```bash
# Switch to minio workspace  
terraform workspace select minio

# Import MinIO EC2 instances (if any)
for instance in $(aws ec2 describe-instances --filters "Name=tag:Name,Values=*minio*" --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' --output text); do
    terraform import module.minio_infrastructure[0].aws_instance.main $instance
done

# Continue with other MinIO resources...
```

### Phase 4: Validation and Testing (30 minutes)

#### Step 4.1: Validate Each Workspace
```bash
# Validate all workspaces
./scripts/deploy.sh all validate

# Plan changes for each workspace (should show no changes if import was successful)
./scripts/deploy.sh dev plan
./scripts/deploy.sh ai-nexus plan
./scripts/deploy.sh minio plan
```

#### Step 4.2: Test Outputs
```bash
# Verify outputs work correctly
./scripts/deploy.sh dev output
./scripts/deploy.sh ai-nexus output
./scripts/deploy.sh minio output
```

### Phase 5: Cleanup Old Configurations (15 minutes)

#### Step 5.1: Archive Old Configurations
```bash
cd /home/daclab-ai/dev/AWS-DevOps

# Create archive directory
mkdir -p archived-terraform/$(date +%Y%m%d-%H%M%S)
ARCHIVE_DIR="archived-terraform/$(date +%Y%m%d-%H%M%S)"

# Move old configurations to archive
mv infrastructure/terraform $ARCHIVE_DIR/infrastructure-terraform
mv apps/ai-nexus-workbench/infrastructure $ARCHIVE_DIR/ai-nexus-infrastructure  
mv apps/ai-nexus-workbench/infra $ARCHIVE_DIR/ai-nexus-infra
mv minio-infrastructure $ARCHIVE_DIR/minio-infrastructure

echo "✅ Old configurations archived to: $ARCHIVE_DIR"
```

#### Step 5.2: Update Documentation
```bash
# Update main README to point to unified terraform
# Update WARP.md with new terraform commands
```

## 🎯 Post-Migration Operations

### Daily Operations

#### Deploy Changes
```bash
# Development environment
./scripts/deploy.sh dev plan
./scripts/deploy.sh dev apply

# Staging environment  
./scripts/deploy.sh staging plan
./scripts/deploy.sh staging apply

# Production (requires approval)
./scripts/deploy.sh prod plan
./scripts/deploy.sh prod apply
```

#### Workspace Management
```bash
# List all workspaces
./scripts/deploy.sh dev workspace list

# Show current workspace
./scripts/deploy.sh dev workspace show

# Switch workspaces (rarely needed with the new script)
terraform workspace select staging
```

### Maintenance Operations

#### State Management
```bash
# List resources in workspace
./scripts/deploy.sh dev state list

# Show specific resource
./scripts/deploy.sh dev state show module.core_infrastructure[0].aws_vpc.main

# Move resources (if needed)
./scripts/deploy.sh dev state mv aws_instance.old aws_instance.new
```

#### Import New Resources
```bash
# Import existing AWS resources
./scripts/deploy.sh dev import module.core_infrastructure[0].aws_instance.new i-1234567890abcdef0
```

#### Backup State
```bash
# Pull current state
./scripts/deploy.sh dev state pull > backups/dev-state-$(date +%Y%m%d).json

# For all workspaces
for workspace in dev staging prod ai-nexus minio; do
    ./scripts/deploy.sh $workspace state pull > backups/${workspace}-state-$(date +%Y%m%d).json
done
```

## 🚨 Rollback Procedures

If issues occur during migration, follow these rollback procedures:

### Immediate Rollback (within 24 hours)
```bash
# 1. Stop using unified terraform
cd /home/daclab-ai/dev/AWS-DevOps

# 2. Restore old configurations
cp -r archived-terraform/TIMESTAMP/* ./

# 3. Restore state files
cp backups/pre-migration-TIMESTAMP/* infrastructure/terraform/core/
# Repeat for other state files

# 4. Initialize old configurations
cd infrastructure/terraform/core
terraform init
terraform plan  # Verify no changes
```

### Partial Rollback (specific workspace)
```bash
# If only one workspace has issues, you can continue with others
# 1. Remove problematic workspace
terraform workspace select default
terraform workspace delete problematic-workspace

# 2. Continue with working workspaces
./scripts/deploy.sh working-workspace plan
```

## 📊 Migration Verification Checklist

- [ ] **Backend Setup Complete**
  - [ ] S3 bucket created and configured
  - [ ] DynamoDB table created for locking
  - [ ] Backend configuration working

- [ ] **Workspaces Created**
  - [ ] dev workspace created
  - [ ] staging workspace created  
  - [ ] prod workspace created
  - [ ] ai-nexus workspace created
  - [ ] minio workspace created

- [ ] **Resources Imported Successfully**
  - [ ] Core infrastructure imported to dev workspace
  - [ ] AI Nexus resources imported to ai-nexus workspace
  - [ ] MinIO resources imported to minio workspace
  - [ ] All terraform plan operations show no changes

- [ ] **Validation Tests Pass**
  - [ ] All workspaces validate successfully
  - [ ] No unexpected changes in terraform plans
  - [ ] Outputs are accessible and correct

- [ ] **Old Configurations Archived**
  - [ ] Original terraform directories moved to archive
  - [ ] State files backed up safely
  - [ ] Documentation updated

- [ ] **Operations Testing**
  - [ ] Deployment script works for all workspaces
  - [ ] State management operations work
  - [ ] Import/export functionality tested

## 🔧 Troubleshooting Common Issues

### Issue: "Resource already exists" during import
```bash
# Solution: The resource may already be managed by terraform
terraform state list | grep resource_name
# If found, skip the import for that resource
```

### Issue: "Backend configuration has changed"
```bash
# Solution: Reconfigure backend
terraform init -reconfigure
```

### Issue: "Workspace not found"
```bash
# Solution: Create the missing workspace
terraform workspace new missing-workspace-name
```

### Issue: Plan shows unexpected changes after import
```bash
# Solution: Check for differences in resource configuration
# Compare with original terraform files and adjust accordingly
terraform plan -detailed-exitcode
```

## 📞 Support and Escalation

### Get Help
```bash
# View detailed help for deployment script
./scripts/deploy.sh --help

# Get terraform help
terraform --help

# Check workspace status
./scripts/deploy.sh dev workspace show
```

### Emergency Contacts
- **DevOps Team**: devops@example.com
- **Infrastructure Lead**: infra-lead@example.com
- **Escalation**: sre-emergency@example.com

### Documentation Links
- [Terraform Workspace Documentation](https://developer.hashicorp.com/terraform/language/state/workspaces)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform State Management](https://developer.hashicorp.com/terraform/language/state)

---

## 🎉 Migration Complete!

Once all steps are completed successfully, you'll have:

✅ **Single unified Terraform configuration** managing all infrastructure  
✅ **Workspace-based environment isolation** with proper state management  
✅ **Centralized modules** eliminating code duplication  
✅ **Consistent variable naming** and configuration structure  
✅ **Unified deployment script** simplifying operations  
✅ **Proper backend configuration** with S3 and DynamoDB  
✅ **Environment-specific configurations** optimized for each use case  

**Next Steps:** Train team members on the new unified workflow and update operational procedures.
