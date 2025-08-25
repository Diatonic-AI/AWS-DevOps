# Terraform Infrastructure

This directory contains Terraform configurations for managing AWS infrastructure.

## Structure

```
terraform/
├── core/                 # Base infrastructure (VPC, IAM, etc.)
├── applications/         # Application-specific infrastructure
├── modules/             # Reusable Terraform modules
├── environments/        # Environment-specific configurations
└── shared/              # Shared resources across environments
```

## Getting Started

1. **Initialize Terraform**:
   ```bash
   cd infrastructure/terraform/core
   terraform init
   ```

2. **Create Workspace**:
   ```bash
   terraform workspace new development
   terraform workspace select development
   ```

3. **Plan and Apply**:
   ```bash
   terraform plan -var-file="development.tfvars"
   terraform apply
   ```

## Best Practices

- Use remote state with S3 backend
- Tag all resources with environment and project
- Follow naming conventions
- Use modules for reusable components
- Always run `terraform plan` before `apply`
- Monitor costs with AWS Cost Explorer

## Free Tier Considerations

- Use t2.micro or t3.micro instance types
- Stay within 750 hours/month for EC2
- Limit S3 usage to 5GB standard storage
- Use db.t2.micro for RDS instances
- Monitor usage regularly
