# Terraform Infrastructure

This directory contains the Terraform infrastructure code for the AWS DevOps project, organized into reusable modules and environment-specific configurations.

## Project Structure

```
terraform/
├── modules/                    # Reusable Terraform modules
│   └── vpc/                   # VPC module
│       ├── main.tf           # VPC resources
│       ├── variables.tf      # Module variables
│       └── outputs.tf        # Module outputs
├── core/                      # Core infrastructure
│   ├── provider.tf           # Provider configuration
│   ├── variables.tf          # Core variables
│   ├── vpc.tf               # VPC implementation using module
│   ├── terraform.dev.tfvars # Development environment variables
│   └── terraform.prod.tfvars# Production environment variables
└── README.md                 # This file
```

## Quick Start

### 1. Prerequisites

- Terraform >= 1.5 installed
- AWS CLI configured with appropriate credentials
- Appropriate AWS permissions for creating VPC resources

### 2. Initialize Terraform

```bash
cd infrastructure/terraform/core
terraform init
```

### 3. Plan and Apply Infrastructure

**Method 1: Using the deployment script (recommended)**
```bash
# Plan and apply in one step
./deploy.sh dev plan-apply

# Or step-by-step
./deploy.sh dev plan      # Creates and saves plan file
./deploy.sh dev apply     # Uses saved plan file
```

**Method 2: Direct Terraform commands**
```bash
# Development environment
terraform plan -var-file="terraform.dev.tfvars" -out="dev-plan.tfplan"
terraform apply "dev-plan.tfplan"

# Production environment
terraform plan -var-file="terraform.prod.tfvars" -out="prod-plan.tfplan"
terraform apply "prod-plan.tfplan"
```

**⚠️ Why use plan files?**
Using the `-out` option saves the execution plan to a file, ensuring that exactly the same changes are applied even if the infrastructure state changes between `plan` and `apply`. This is a Terraform best practice for production deployments.

## Deployment Script

The `deploy.sh` script provides a convenient wrapper around Terraform commands with built-in best practices:

```bash
# Available commands
./deploy.sh <environment> <action> [additional_args]

# Examples:
./deploy.sh dev init          # Initialize Terraform
./deploy.sh dev validate      # Validate configuration
./deploy.sh dev plan          # Create and save plan file
./deploy.sh dev apply         # Apply from saved plan file
./deploy.sh dev plan-apply    # Plan and apply in one step
./deploy.sh dev output        # Show output values
./deploy.sh dev destroy       # Destroy infrastructure
```

**Features:**
- ✅ Automatic plan file management
- ✅ Environment validation
- ✅ AWS credential verification
- ✅ Safety confirmations for destructive operations
- ✅ Colored output and progress indicators
- ✅ Error handling and validation

## VPC Module Features

The VPC module creates a comprehensive networking foundation with:

### Network Architecture
- **Multi-AZ deployment** across 3 availability zones
- **Three-tier subnet architecture**:
  - Public subnets (for load balancers, NAT gateways)
  - Private subnets (for application servers)
  - Data subnets (for databases, isolated workloads)

### Connectivity
- Internet Gateway for public internet access
- NAT Gateways for secure outbound internet access from private subnets
- VPC Endpoints for cost-effective AWS service access
- Route tables configured for each tier

### Security
- Default security group with restricted rules
- VPC Flow Logs for network monitoring
- Subnet groups for RDS and ElastiCache
- Configurable CIDR blocks and security settings

### Cost Optimization
- Environment-specific NAT Gateway configuration:
  - Single NAT Gateway for dev/staging (cost-effective)
  - Multiple NAT Gateways for prod (high availability)
- VPC Endpoints to reduce data transfer costs
- Optional features to control costs in non-production environments

## Environment-Specific Configurations

### Development Environment
- Single NAT Gateway for cost savings
- Relaxed security settings
- Minimal monitoring and logging
- No backups enabled
- Open CIDR blocks for development access

### Production Environment
- Multiple NAT Gateways for high availability
- Enhanced security features enabled
- Comprehensive monitoring and logging
- Backup retention for 90 days
- Restrictive CIDR blocks

## Available Variables

### Core Variables
| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `project_name` | Name of the project | `string` | `"aws-devops"` |
| `environment` | Environment (dev/staging/prod) | `string` | - |
| `aws_region` | AWS region | `string` | `"us-east-2"` |
| `aws_profile` | AWS profile | `string` | `"default"` |

### VPC Configuration
| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `vpc_cidr_override` | Override default VPC CIDR | `string` | `null` |
| `allowed_cidr_blocks` | Allowed CIDR blocks | `list(string)` | `[]` |

### Feature Flags
| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `feature_flags.enable_nat_gateway` | Enable NAT Gateway | `bool` | `true` |
| `feature_flags.enable_vpc_endpoints` | Enable VPC Endpoints | `bool` | `true` |
| `feature_flags.enable_flow_logs` | Enable VPC Flow Logs | `bool` | `true` |
| `feature_flags.enable_cloudtrail` | Enable CloudTrail | `bool` | `true` |

## VPC Module Usage

The VPC module can be used independently in other projects:

```hcl
module "vpc" {
  source = "../modules/vpc"
  
  vpc_name = "my-vpc"
  vpc_cidr = "10.0.0.0/16"
  
  availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  data_subnet_cidrs    = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  
  enable_nat_gateway = true
  enable_vpc_endpoints = true
  enable_flow_logs = true
  
  environment = "dev"
  
  tags = {
    Project = "MyProject"
    Environment = "dev"
  }
}
```

## Outputs

The infrastructure provides the following outputs:

- VPC ID and CIDR block
- Subnet IDs for all tiers (public, private, data)
- Internet Gateway and NAT Gateway IDs
- Database and ElastiCache subnet group names
- Route table IDs

## Best Practices

### Security
- Use restrictive CIDR blocks in production
- Enable VPC Flow Logs for monitoring
- Regularly review security group rules
- Use VPC Endpoints to keep traffic within AWS

### Cost Optimization
- Use single NAT Gateway in non-production environments
- Enable VPC Endpoints to reduce data transfer costs
- Regularly review and clean up unused resources
- Monitor costs with AWS Cost Explorer

### High Availability
- Deploy across multiple AZs
- Use multiple NAT Gateways in production
- Plan for subnet capacity and growth
- Implement proper backup and recovery procedures

## Troubleshooting

### Common Issues

1. **Insufficient IP addresses**: Increase subnet CIDR sizes or add more subnets
2. **NAT Gateway connectivity**: Check route table associations and security groups
3. **VPC Endpoint access**: Verify endpoint policies and route table configuration
4. **Cross-AZ communication**: Ensure proper subnet and security group configuration

### Validation Commands

```bash
# Validate Terraform configuration
terraform validate

# Check formatting
terraform fmt -check

# Plan with specific variable file
terraform plan -var-file="terraform.dev.tfvars"

# Show current state
terraform show

# List all resources
terraform state list
```

## Free Tier Considerations

- Use t2.micro or t3.micro instance types
- Stay within 750 hours/month for EC2
- Limit S3 usage to 5GB standard storage
- Use db.t2.micro for RDS instances
- Monitor usage regularly
- VPC, subnets, and route tables are free
- NAT Gateways incur charges (~$45/month each)
- VPC Flow Logs have CloudWatch Logs charges

## Next Steps

After deploying the VPC infrastructure:

1. **Deploy compute resources** (EC2, EKS, Lambda)
2. **Set up databases** (RDS, DynamoDB)
3. **Configure monitoring** (CloudWatch, X-Ray)
4. **Implement CI/CD pipelines** 
5. **Set up application load balancers**
6. **Configure DNS and certificates**

## Contributing

When adding new infrastructure:

1. Follow the established module pattern
2. Include comprehensive variable validation
3. Add appropriate outputs
4. Update documentation
5. Test in development environment first
6. Follow security best practices

## Support

For questions or issues:

1. Check the troubleshooting section above
2. Review AWS documentation for specific services
3. Consult Terraform AWS provider documentation
4. Open an issue in the project repository
