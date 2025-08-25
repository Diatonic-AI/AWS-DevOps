# AWS DevOps Infrastructure & Applications

This repository manages AWS infrastructure, applications, and DevOps workflows using Infrastructure as Code (IaC) principles and best practices.

## 🏗️ Repository Structure

```
AWS-DevOps/
├── applications/          # Application deployments and configurations
├── infrastructure/        # Infrastructure as Code (Terraform, CDK, CloudFormation)
├── scripts/              # Automation and utility scripts
├── docs/                 # Documentation and guides
├── monitoring/           # Monitoring, logging, and alerting configurations
├── security/             # Security configurations and compliance
├── backups/              # Backup scripts and restoration procedures
├── templates/            # Reusable templates for common patterns
└── .github/workflows/    # CI/CD pipeline definitions
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI v2+ installed and configured
- Terraform >= 1.6.0
- AWS CDK v2+ (for TypeScript/Python projects)
- Docker (for containerized applications)
- Git configured with your credentials

### Initial Setup

1. **Clone and Navigate**:
   ```bash
   cd ~/DEV/AWS-DevOps
   ```

2. **Configure AWS Credentials**:
   ```bash
   aws configure
   # Or use AWS SSO: aws configure sso
   ```

3. **Set Default Region** (if not already set):
   ```bash
   aws configure set default.region us-east-2
   ```

4. **Verify Configuration**:
   ```bash
   aws sts get-caller-identity
   ```

## 💰 Cost Management & Free Tier

⚠️ **IMPORTANT**: This repository is designed to work within AWS Free Tier limits. Always monitor your usage!

- 📊 **[Free Tier Documentation](./docs/Free-Tier.md)** - Comprehensive guide to AWS Free Tier limits
- 💡 Set up billing alerts before deploying any resources
- 🏷️ Tag all resources with `Project=DevOps` and `Environment=<env>`
- 🔄 Regularly clean up unused resources

### Quick Free Tier Check

```bash
# Check current EC2 usage
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' --output table

# Monitor S3 usage
aws s3 ls --summarize --human-readable --recursive s3://your-bucket-name

# Check RDS instances
aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass]' --output table
```

## 🏛️ Infrastructure Management

### Terraform Projects

Located in `infrastructure/terraform/`:

- **Core Infrastructure**: VPC, subnets, security groups, IAM
- **Application Infrastructure**: ECS, EKS, Lambda, databases
- **Monitoring Stack**: CloudWatch, alerting, dashboards
- **Security**: KMS, Secrets Manager, WAF configurations

### CDK Projects

Located in `infrastructure/cdk/`:

- **TypeScript Projects**: Modern infrastructure definitions
- **Python Projects**: Data and ML infrastructure
- **Shared Constructs**: Reusable infrastructure patterns

### Usage Examples

```bash
# Initialize Terraform workspace
cd infrastructure/terraform/core
terraform init
terraform workspace select development
terraform plan
terraform apply

# Deploy CDK stack
cd infrastructure/cdk/app-stack
npm install
cdk bootstrap  # First time only
cdk deploy --profile development
```

## 🔧 Application Deployment

Applications are organized by technology and deployment pattern:

```
applications/
├── serverless/           # Lambda functions and serverless apps
├── containers/           # Docker containers and ECS/EKS deployments  
├── static-sites/         # S3 + CloudFront static websites
├── databases/            # Database schemas and migrations
└── microservices/        # Microservice architectures
```

### Deployment Patterns

- **Serverless**: AWS Lambda + API Gateway + DynamoDB
- **Containerized**: ECS Fargate or EKS with ALB
- **Static Sites**: S3 + CloudFront + Route 53
- **Traditional**: EC2 with Auto Scaling Groups

## 🔒 Security & Compliance

Security configurations and best practices:

- **IAM Policies**: Least privilege access policies
- **VPC Security**: Network ACLs and security groups
- **Secrets Management**: AWS Secrets Manager integration
- **Compliance**: SOC 2, GDPR, HIPAA configurations
- **Security Scanning**: Automated vulnerability scans

### Security Checklist

- [ ] Enable AWS CloudTrail for all regions
- [ ] Configure AWS Config for compliance monitoring
- [ ] Set up AWS GuardDuty for threat detection
- [ ] Enable VPC Flow Logs
- [ ] Implement AWS WAF for web applications
- [ ] Use AWS KMS for encryption at rest
- [ ] Regular security group audits

## 📊 Monitoring & Observability

Comprehensive monitoring setup:

- **Metrics**: CloudWatch custom metrics and dashboards
- **Logging**: Centralized logging with CloudWatch Logs
- **Alerting**: SNS notifications for critical events
- **Tracing**: AWS X-Ray for application performance
- **Cost Monitoring**: Daily cost reports and budget alerts

### Key Monitoring Commands

```bash
# View CloudWatch alarms
aws cloudwatch describe-alarms --state-value ALARM

# Check recent logs
aws logs describe-log-groups --query 'logGroups[].[logGroupName,storedBytes]'

# Monitor costs
aws ce get-cost-and-usage --time-period Start=2025-08-01,End=2025-08-31 --granularity MONTHLY --metrics BlendedCost
```

## 🔄 CI/CD Pipeline

Automated deployment pipelines using GitHub Actions:

- **Infrastructure**: Terraform plan/apply on PR/merge
- **Applications**: Build, test, and deploy applications
- **Security**: Automated security scanning and compliance checks
- **Rollback**: Automated rollback procedures

### Pipeline Structure

```yaml
# .github/workflows/infrastructure.yml
name: Infrastructure Deployment
on:
  push:
    branches: [main]
    paths: [infrastructure/**]
  
jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      # ... rest of pipeline
```

## 📁 Directory Details

### Infrastructure (`infrastructure/`)

- **terraform/**: Infrastructure as Code using Terraform
  - `core/`: Base infrastructure (VPC, IAM, etc.)
  - `applications/`: Application-specific infrastructure
  - `modules/`: Reusable Terraform modules
  
- **cdk/**: AWS CDK projects
  - `typescript/`: CDK projects in TypeScript
  - `python/`: CDK projects in Python
  
- **cloudformation/**: CloudFormation templates for legacy/specific use cases

### Applications (`applications/`)

- **serverless/**: Lambda functions and serverless architectures
- **containers/**: Containerized applications (Docker, ECS, EKS)
- **static-sites/**: Static websites and SPAs
- **databases/**: Database schemas, migrations, and seed data

### Scripts (`scripts/`)

- **deployment/**: Deployment automation scripts
- **maintenance/**: System maintenance and cleanup scripts
- **monitoring/**: Custom monitoring and alerting scripts
- **backup/**: Backup and disaster recovery scripts

## 🛠️ Development Workflow

1. **Feature Branch**: Create feature branch for changes
2. **Local Development**: Test changes locally with localstack/terraform
3. **Pull Request**: Submit PR with infrastructure/application changes
4. **Automated Testing**: CI pipeline runs tests and security scans
5. **Code Review**: Team reviews infrastructure and security implications
6. **Deployment**: Merge triggers automated deployment to staging
7. **Production**: Manual approval gate for production deployment

### Local Development Setup

```bash
# Install development dependencies
npm install -g aws-cdk@latest
pip install localstack
docker run -d --name localstack -p 4566:4566 localstack/localstack

# Run tests
cd infrastructure/terraform/core
terraform fmt
terraform validate
terraform plan

# Lint and security scan
tflint
checkov -f main.tf
```

## 🔧 Useful Commands

### AWS CLI Essentials

```bash
# Account information
aws sts get-caller-identity
aws sts get-account-authorization-details

# Resource listing
aws ec2 describe-instances --output table
aws s3 ls
aws rds describe-db-instances
aws lambda list-functions

# Cost and billing
aws ce get-cost-and-usage --time-period Start=2025-08-01,End=2025-08-31 --granularity DAILY --metrics BlendedCost
aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text)
```

### Terraform Operations

```bash
# Workspace management
terraform workspace list
terraform workspace select development
terraform workspace new staging

# State management
terraform state list
terraform state show resource_name
terraform import aws_instance.example i-1234567890abcdef0

# Planning and applying
terraform plan -var-file="development.tfvars"
terraform apply -target=module.vpc
terraform destroy -target=resource.example
```

### CDK Commands

```bash
# Project setup
cdk init app --language typescript
cdk bootstrap --profile development

# Deployment operations
cdk ls
cdk diff
cdk deploy --all --require-approval never
cdk destroy --force
```

## 📚 Documentation

- **[Free Tier Guide](./docs/Free-Tier.md)**: Complete AWS Free Tier reference
- **[Security Guidelines](./docs/Security.md)**: Security best practices and configurations
- **[Deployment Guide](./docs/Deployment.md)**: Step-by-step deployment instructions
- **[Monitoring Guide](./docs/Monitoring.md)**: Monitoring and observability setup
- **[Troubleshooting](./docs/Troubleshooting.md)**: Common issues and solutions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Contribution Guidelines

- Follow infrastructure as code best practices
- Include documentation for new features
- Add tests for infrastructure changes
- Update cost estimates for new resources
- Ensure changes work within free tier limits

## 📋 TODO

- [ ] Set up automated cost alerts
- [ ] Implement blue-green deployment patterns
- [ ] Add infrastructure testing with Terratest
- [ ] Create disaster recovery procedures
- [ ] Set up cross-region backup strategies
- [ ] Implement infrastructure drift detection
- [ ] Add compliance scanning automation

## 📞 Support

- **AWS Documentation**: https://docs.aws.amazon.com/
- **Terraform Documentation**: https://www.terraform.io/docs/
- **AWS CDK Documentation**: https://docs.aws.amazon.com/cdk/
- **Internal Documentation**: See `docs/` directory

---

**⚠️ Cost Warning**: Always monitor your AWS usage and set up billing alerts. While this repository is designed for free tier usage, AWS charges apply for resources beyond free limits.

**🔐 Security Notice**: Never commit AWS credentials or secrets to this repository. Use AWS IAM roles and temporary credentials for all operations.
