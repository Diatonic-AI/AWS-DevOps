# 🚀 AWS-DevOps Unified Terraform Management

## Overview

This directory contains the **unified Terraform management system** that consolidates all AWS infrastructure and applications into a single, cohesive configuration. This system addresses the previous fragmentation across multiple separate Terraform roots and provides a streamlined approach to infrastructure management.

## 🎯 Key Benefits

- ✅ **Single Source of Truth** - One Terraform configuration manages all infrastructure
- ✅ **Workspace Isolation** - Environment and application isolation using Terraform workspaces
- ✅ **Centralized Modules** - Reusable modules eliminate code duplication
- ✅ **Consistent Naming** - Standardized resource naming and variable structure
- ✅ **Unified Backend** - S3 + DynamoDB backend with proper state isolation
- ✅ **Cost Optimized** - Environment-specific configurations optimized for cost
- ✅ **Production Ready** - Security and compliance best practices built-in

## 📁 Directory Structure

```
unified-terraform/
├── main.tf                    # Main Terraform configuration with workspace logic
├── variables.tf               # Centralized variable definitions
├── outputs.tf                # Consolidated outputs
├── versions.tf               # Provider version constraints
├── modules/                  # Centralized, reusable modules
│   ├── core-infrastructure/ # VPC, networking, shared resources
│   ├── ai-nexus-workbench/  # AI Nexus application resources
│   ├── minio/               # MinIO infrastructure
│   └── shared/              # Common utilities and resources
├── environments/            # Environment-specific configurations
│   ├── dev/                # Development environment settings
│   ├── staging/            # Staging environment settings
│   └── prod/               # Production environment settings
├── scripts/                # Automation and deployment scripts
│   ├── deploy.sh           # Unified deployment script
│   └── setup-backend.tf    # Backend initialization
├── MIGRATION_GUIDE.md      # Detailed migration instructions
└── README.md              # This file
```

## 🏗️ Architecture

### Workspace Strategy

The unified system uses Terraform workspaces to provide isolation between different environments and applications:

| Workspace | Purpose | Environment | Resources |
|-----------|---------|-------------|-----------|
| `dev` | Development environment | Development | Core + All applications |
| `staging` | Pre-production testing | Staging | Core + Production-like apps |
| `prod` | Production environment | Production | Core + All applications |
| `ai-nexus` | AI Nexus Workbench | Development | AI Nexus specific resources |
| `minio` | MinIO infrastructure | Development | MinIO specific resources |

### Module Architecture

- **Core Infrastructure Module**: VPC, networking, security groups, shared S3 buckets
- **AI Nexus Workbench Module**: Cognito, API Gateway, Lambda, DynamoDB, application-specific resources
- **MinIO Module**: MinIO server infrastructure, storage, and networking
- **Shared Modules**: Common utilities, monitoring, backup configurations

## 🚀 Quick Start

### Prerequisites

- Terraform 1.5+ installed
- AWS CLI configured with appropriate permissions
- Access to create S3 buckets and DynamoDB tables

### 1. Initial Setup (First Time Only)

```bash
cd /home/daclab-ai/dev/AWS-DevOps/unified-terraform

# Setup backend infrastructure
./scripts/deploy.sh backend setup

# Initialize Terraform
./scripts/deploy.sh dev init
```

### 2. Deploy Development Environment

```bash
# Plan changes
./scripts/deploy.sh dev plan

# Apply changes
./scripts/deploy.sh dev apply
```

### 3. Deploy AI Nexus Workbench

```bash
# Initialize and deploy AI Nexus
./scripts/deploy.sh ai-nexus init
./scripts/deploy.sh ai-nexus plan
./scripts/deploy.sh ai-nexus apply
```

## 📋 Common Operations

### Environment Management

```bash
# Deploy to different environments
./scripts/deploy.sh dev apply        # Development
./scripts/deploy.sh staging apply    # Staging
./scripts/deploy.sh prod apply       # Production (requires approval)

# Validate all configurations
./scripts/deploy.sh all validate

# Format all Terraform files
./scripts/deploy.sh all format
```

### Workspace Operations

```bash
# List all workspaces
./scripts/deploy.sh dev workspace list

# Show current workspace
./scripts/deploy.sh dev workspace show
```

### State Management

```bash
# List resources in a workspace
./scripts/deploy.sh dev state list

# Show specific resource
./scripts/deploy.sh dev state show module.core_infrastructure[0].aws_vpc.main

# Import existing resources
./scripts/deploy.sh dev import module.core_infrastructure[0].aws_instance.example i-1234567890abcdef0
```

### Outputs and Information

```bash
# Show workspace outputs
./scripts/deploy.sh dev output

# Show current state
./scripts/deploy.sh dev show
```

## ⚙️ Configuration

### Environment-Specific Settings

Each environment has its own configuration file with optimized settings:

- **Development** (`environments/dev/terraform.tfvars`):
  - Cost-optimized (single AZ, NAT instances)
  - Minimal security features
  - Short log retention
  - Development-friendly settings

- **Production** (`environments/prod/terraform.tfvars`):
  - High availability (multi-AZ)
  - Full security features enabled
  - Compliance configurations
  - Long retention periods

### Variable Overrides

You can override variables using:

```bash
# Using environment-specific tfvars
./scripts/deploy.sh dev plan --var-file=environments/dev/terraform.tfvars

# Using additional overrides
./scripts/deploy.sh prod plan --var-file=prod-overrides.tfvars
```

## 🔒 Security Features

- **Backend Encryption**: State files encrypted at rest in S3
- **State Locking**: DynamoDB prevents concurrent modifications
- **Workspace Isolation**: Each environment/application has isolated state
- **IAM Best Practices**: Least privilege access patterns
- **VPC Security**: Proper security groups and NACLs
- **Compliance Ready**: CloudTrail, Config, GuardDuty integration

## 💰 Cost Optimization

- **Environment-Specific Sizing**: Right-sized resources per environment
- **Scheduled Scaling**: Automatic scale-down during off-hours
- **Spot Instances**: Cost savings in development environments
- **Resource Sharing**: Common resources shared across applications
- **Free Tier Optimized**: Development environments stay within AWS Free Tier

## 🔄 CI/CD Integration

The unified system integrates with existing GitHub Actions workflows:

```yaml
# Example workflow step
- name: Deploy Infrastructure
  run: |
    cd unified-terraform
    ./scripts/deploy.sh ${{ env.ENVIRONMENT }} plan
    ./scripts/deploy.sh ${{ env.ENVIRONMENT }} apply
```

## 🛠️ Troubleshooting

### Common Issues

1. **Backend Configuration Changed**
   ```bash
   terraform init -reconfigure
   ```

2. **Workspace Doesn't Exist**
   ```bash
   terraform workspace new <workspace-name>
   ```

3. **State Lock Issues**
   ```bash
   # Force unlock (use with caution)
   terraform force-unlock <lock-id>
   ```

### Validation

```bash
# Validate configuration
./scripts/deploy.sh dev validate

# Check formatting
terraform fmt -check -recursive
```

## 📊 Monitoring and Observability

- **CloudWatch Integration**: Centralized logging and monitoring
- **Cost Monitoring**: Automated cost alerts and reporting
- **Performance Monitoring**: Application and infrastructure metrics
- **Security Monitoring**: GuardDuty, Config, and CloudTrail integration

## 🔗 Related Documentation

- [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) - Detailed migration instructions
- [AWS-DevOps WARP.md](../WARP.md) - Project overview and operations
- [Terraform Workspace Documentation](https://developer.hashicorp.com/terraform/language/state/workspaces)

## 🤝 Contributing

### Making Changes

1. **Plan First**: Always run `terraform plan` before applying changes
2. **Test in Dev**: Test changes in development workspace first
3. **Validate**: Ensure `terraform validate` passes
4. **Format**: Run `terraform fmt` before committing
5. **Document**: Update documentation for significant changes

### Module Development

```bash
# Test module changes
cd modules/your-module
terraform init
terraform validate
```

### Adding New Environments

1. Create new tfvars file in `environments/`
2. Add workspace mapping in `main.tf`
3. Update deployment script if needed
4. Test thoroughly before production use

## 📞 Support

- **Documentation**: Check WARP.md and this README first
- **Issues**: Create GitHub issues for bugs or feature requests
- **Urgent**: Contact DevOps team for production issues

---

## 🎯 Success Metrics

With the unified system, you can expect:

- 📉 **50% reduction** in deployment complexity
- ⚡ **Faster deployments** with consistent tooling
- 🔒 **Improved security** with standardized configurations
- 💰 **Cost optimization** through environment-specific settings
- 🚀 **Better scalability** with modular architecture
- 🔄 **Simplified maintenance** with centralized management

**Welcome to simplified, unified infrastructure management!** 🎉
