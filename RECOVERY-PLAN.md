# 🚀 AWS Infrastructure Recovery Plan

**Account ID:** 313476888312  
**Region:** us-east-2  
**Created:** 2025-09-07 17:23 UTC

## 🎯 Executive Summary

Based on the comprehensive AWS resource discovery, your infrastructure is **actively deployed and serving traffic** at `diatonic.ai` and subdomains. The missing repository components can be recovered through reverse-engineering from the deployed infrastructure.

**Key Finding:** This is not a "lost" infrastructure but rather missing source code/configuration files for existing, operational systems.

## 📊 Current Infrastructure Status

### ✅ What's Working
- **DNS:** diatonic.ai domain fully configured with multiple subdomains
- **CDN:** CloudFront distributions serving traffic
- **Load Balancing:** Application Load Balancer active
- **Containers:** ECS service running nginx:alpine (Task Definition v18)
- **Networking:** Complete VPCs with 3-tier subnet architecture
- **Database:** 6 DynamoDB tables for production application
- **Authentication:** Cognito User Pool with Lambda triggers
- **SSL/TLS:** Valid ACM certificates in both regions

### ❌ What's Missing
- **Source Code:** Application code, Dockerfiles, Lambda functions
- **Infrastructure Code:** Terraform definitions for deployed resources
- **CI/CD Pipelines:** Deployment automation and container registries
- **Configuration Management:** Environment variables, secrets

## 🔧 Recovery Strategy

### Phase 1: Infrastructure as Code Recovery (Priority 1)

#### Step 1: Create Terraform Backend
```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://aws-devops-terraform-state-313476888312-us-east-2

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name aws-devops-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=aws-devops Key=Environment,Value=shared
```

#### Step 2: Import Existing Resources
Create reverse-engineered Terraform files and import existing resources:

```bash
cd infrastructure/terraform/core

# Import VPCs
terraform import aws_vpc.dev_vpc vpc-01e885e91c54deb46
terraform import aws_vpc.prod_vpc vpc-06d0d2402de4b1ff4

# Import Route 53
terraform import aws_route53_zone.diatonic_ai Z032094313J9CQ17JQ2OQ

# Import CloudFront
terraform import aws_cloudfront_distribution.diatonic_ai EB3GDEPQ1RC9T

# Import Load Balancer
terraform import aws_lb.dev_alb arn:aws:elasticloadbalancing:us-east-2:313476888312:loadbalancer/app/aws-devops-dev-alb/559404851

# Import ECS Cluster and Service
terraform import aws_ecs_cluster.dev_cluster aws-devops-dev-cluster
terraform import aws_ecs_service.dev_service aws-devops-dev-cluster/aws-devops-dev-service
```

#### Step 3: Generate Terraform Configuration
Based on the discovered infrastructure, create these Terraform files:

**`infrastructure/terraform/core/main.tf`** (Core resources)
**`infrastructure/terraform/core/vpc.tf`** (VPC configuration matching discovered subnets)
**`infrastructure/terraform/core/ecs.tf`** (ECS cluster and service)
**`infrastructure/terraform/core/route53.tf`** (DNS configuration)
**`infrastructure/terraform/core/cloudfront.tf`** (CDN distribution)

### Phase 2: Application Recovery (Priority 2)

#### Step 1: Examine Current ECS Task
The ECS task is running `nginx:alpine` with these environment variables:
- `DOMAIN_NAME=dev.diatonic.ai`
- `PROJECT_NAME=aws-devops`
- `ENVIRONMENT=development`
- `NGINX_PORT=80`

#### Step 2: Reverse-Engineer Application Structure
Create basic application structure:

```bash
# Create application directories
mkdir -p applications/web/{src,docker,config}
mkdir -p applications/api/{src,docker,config}

# Create basic Dockerfile for the nginx container
cat > applications/web/docker/Dockerfile << EOF
FROM nginx:alpine

# Copy nginx configuration
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/default.conf /etc/nginx/conf.d/default.conf

# Copy static assets
COPY src/ /usr/share/nginx/html/

# Environment setup
ENV NGINX_PORT=80
ENV DOMAIN_NAME=dev.diatonic.ai
ENV PROJECT_NAME=aws-devops
ENV ENVIRONMENT=development

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF
```

#### Step 3: Lambda Function Recovery
The production environment has two Lambda functions that can be downloaded:

```bash
# Create Lambda function directories
mkdir -p applications/lambda/{cognito-triggers,api-handler}

# Download Lambda function code (the signed URL provides temporary access)
# Note: You'll need to recreate the functions as the signed URLs expire
```

### Phase 3: CI/CD Pipeline Recovery (Priority 3)

#### Step 1: Create Container Registry
```bash
# Create ECR repositories for container images
aws ecr create-repository --repository-name aws-devops/web-app --region us-east-2
aws ecr create-repository --repository-name aws-devops/api --region us-east-2
```

#### Step 2: Enhance GitHub Actions Workflows
Update existing workflows in `.github/workflows/` to:
1. Build and push container images to ECR
2. Update ECS task definitions with new images
3. Deploy Lambda functions from source code

### Phase 4: Database and State Recovery (Priority 4)

#### Step 1: Document DynamoDB Schema
The production environment has 6 DynamoDB tables:
- `diatonic-prod-ai-conversations`
- `diatonic-prod-ai-models`  
- `diatonic-prod-ai-sessions`
- `diatonic-prod-projects`
- `diatonic-prod-user-files`
- `diatonic-prod-users`

Create Terraform resources to manage these tables.

#### Step 2: Cognito User Pool Management
Import and manage the existing user pool: `us-east-2_hnlgmxl8t`

## 📝 Detailed Recovery Commands

### Immediate Actions (Next 2 Hours)

1. **Create Terraform Backend:**
```bash
# Set up backend configuration
cd infrastructure/terraform/core
cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "aws-devops-terraform-state-313476888312-us-east-2"
    key            = "core/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "aws-devops-terraform-state-lock"
    encrypt        = true
  }
}
EOF
```

2. **Initialize Terraform:**
```bash
terraform init
```

3. **Create Environment Variable Files:**
```bash
# Create missing tfvars files based on discovered resources
cat > terraform.dev.tfvars << EOF
environment = "development"
project_name = "aws-devops"
aws_region = "us-east-2"

# VPC Configuration (discovered from AWS)
vpc_id = "vpc-01e885e91c54deb46"
vpc_cidr = "10.1.0.0/16"

# Domain Configuration
domain_name = "dev.diatonic.ai"
certificate_arn = "arn:aws:acm:us-east-2:313476888312:certificate/5241d9e1-cdee-4674-b625-3701fca53cd7"

# ECS Configuration
cluster_name = "aws-devops-dev-cluster"
service_name = "aws-devops-dev-service"
container_image = "nginx:alpine"
EOF
```

### Short-term Recovery (Next 1 Week)

1. **Reverse-Engineer Terraform Files:**
   - Create VPC configuration matching discovered subnets
   - Recreate ECS task definitions
   - Import CloudFront and Route 53 configurations

2. **Application Code Recovery:**
   - Create basic web application structure
   - Implement proper Dockerfile
   - Set up local development environment

3. **CI/CD Pipeline Setup:**
   - Configure ECR repositories
   - Update GitHub Actions to build and deploy containers
   - Implement proper secret management

### Long-term Optimization (Next 1 Month)

1. **Infrastructure Improvements:**
   - Implement proper Terraform modules
   - Add monitoring and alerting
   - Optimize for cost and performance

2. **Application Enhancement:**
   - Recover/rebuild Lambda function logic
   - Implement proper application architecture
   - Add comprehensive testing

3. **Operational Excellence:**
   - Implement comprehensive monitoring
   - Set up proper backup procedures
   - Document operational runbooks

## 🔍 Investigation Commands

To gather more specific information about your infrastructure:

```bash
# Get detailed ECS task definition (includes full environment and configuration)
aws ecs describe-task-definition --task-definition aws-devops-dev-task:18 > task-definition-v18.json

# Export Route 53 configuration
aws route53 list-resource-record-sets --hosted-zone-id Z032094313J9CQ17JQ2OQ > dns-records.json

# Get CloudFront distribution configuration
aws cloudfront get-distribution --id EB3GDEPQ1RC9T > cloudfront-config.json

# Export VPC configuration
aws ec2 describe-vpcs --vpc-ids vpc-01e885e91c54deb46 vpc-06d0d2402de4b1ff4 > vpc-config.json
aws ec2 describe-subnets --filters Name=vpc-id,Values=vpc-01e885e91c54deb46,vpc-06d0d2402de4b1ff4 > subnet-config.json

# Get Lambda function details
aws lambda get-function --function-name diatonic-prod-api-handler > lambda-api-handler.json
aws lambda get-function --function-name diatonic-prod-cognito-triggers > lambda-cognito-triggers.json

# Export DynamoDB table schemas
for table in diatonic-prod-ai-conversations diatonic-prod-ai-models diatonic-prod-ai-sessions diatonic-prod-projects diatonic-prod-user-files diatonic-prod-users; do
  aws dynamodb describe-table --table-name $table > "dynamodb-${table}.json"
done
```

## ⚠️ Critical Considerations

1. **Production Impact:** Your production infrastructure is actively serving traffic. All changes should be tested in development first.

2. **Data Preservation:** The DynamoDB tables contain production data. Do not modify or delete these during recovery.

3. **SSL Certificates:** You have valid certificates that should be preserved and referenced in new configurations.

4. **DNS Management:** The Route 53 hosted zone is serving live traffic. Any DNS changes should be carefully planned.

5. **Cost Optimization:** While recovering, consider implementing the Free Tier monitoring scripts that exist in your repository.

## 📞 Success Criteria

Recovery is complete when:
- [ ] Terraform can manage all existing infrastructure
- [ ] CI/CD pipeline can deploy applications
- [ ] Source code is recovered or recreated
- [ ] Documentation matches actual infrastructure
- [ ] Development workflow is fully operational

This recovery plan provides a systematic approach to rebuilding your repository while preserving your operational infrastructure.
