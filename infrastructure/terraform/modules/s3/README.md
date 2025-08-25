# Enterprise S3 Module

This Terraform module creates an enterprise-grade S3 infrastructure with multiple purpose-built buckets, comprehensive security controls, lifecycle management, and cross-region replication capabilities.

## Features

### 🏗️ **Multi-Purpose Bucket Architecture**
- **Application Bucket**: Store application data, user uploads, and dynamic content
- **Backup Bucket**: Automated backups with aggressive lifecycle transitions
- **Logs Bucket**: Centralized logging with compliance-grade retention
- **Static Assets Bucket**: CDN-ready static content with optional public access
- **Compliance Bucket**: Long-term audit storage with no expiration
- **Data Lake Bucket**: Analytics-ready data storage (optional)

### 🔒 **Enterprise Security**
- **Encryption**: Server-side encryption with KMS or AES256
- **Access Control**: Public access blocking by default, SSL-only policies
- **Versioning**: Object versioning with MFA delete protection
- **VPC Integration**: Seamless integration with VPC endpoints
- **IAM Roles**: Least-privilege access for cross-region replication

### 💰 **Cost Optimization**
- **Intelligent Tiering**: Automatic cost optimization based on access patterns
- **Lifecycle Policies**: Automated transitions to cheaper storage classes
- **Cross-Region Replication**: Configurable for critical data only
- **Request Payer**: Configurable cost allocation

### 🔄 **Disaster Recovery**
- **Cross-Region Replication**: Automatic replication to disaster recovery region
- **Versioning**: Protection against accidental deletion or corruption
- **Backup Retention**: Configurable retention policies per environment

### 📊 **Monitoring & Compliance**
- **Access Logging**: Comprehensive audit trails
- **CloudWatch Metrics**: Detailed monitoring and alerting
- **Inventory Reports**: Daily inventory for cost analysis and compliance
- **Event Notifications**: Real-time event processing

## Usage

### Basic Usage

```hcl
module "s3" {
  source = "./modules/s3"
  
  name_prefix = "mycompany-prod"
  environment = "production"
  region      = "us-east-2"
  
  # VPC Integration
  vpc_id = module.vpc.vpc_id
  vpc_endpoint_route_table_ids = module.vpc.route_table_ids
  
  tags = {
    Project     = "MyProject"
    Environment = "production"
  }
}
```

### Advanced Configuration

```hcl
module "s3" {
  source = "./modules/s3"
  
  name_prefix = "mycompany-prod"
  environment = "production"
  region      = "us-east-2"
  
  # Bucket Selection
  create_application_bucket   = true
  create_backup_bucket       = true
  create_logs_bucket         = true
  create_static_assets_bucket = true
  create_compliance_bucket   = true
  create_data_lake_bucket    = true
  
  # Security Configuration
  enable_versioning           = true
  enable_mfa_delete          = true  # Requires MFA setup
  enable_server_side_encryption = true
  kms_key_id                 = "arn:aws:kms:us-east-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  
  # Public Access (be careful!)
  public_read_buckets = ["static-assets"]
  
  # Cross-Region Replication
  enable_cross_region_replication = true
  replication_destination_region  = "us-west-2"
  replicate_buckets              = ["application", "compliance"]
  
  # Static Website Hosting
  enable_static_website = true
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://mycompany.com"]
      max_age_seconds = 3000
    }
  ]
  
  # Monitoring
  enable_metrics              = true
  enable_inventory           = true
  enable_event_notifications = true
  notification_sns_topic_arn = "arn:aws:sns:us-east-2:123456789012:s3-events"
  
  # VPC Integration
  vpc_id = module.vpc.vpc_id
  vpc_endpoint_route_table_ids = concat(
    module.vpc.public_route_table_ids,
    module.vpc.private_route_table_ids
  )
  
  providers = {
    aws.replica = aws.us_west_2
  }
}

# Provider for cross-region replication
provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}
```

## Bucket Types and Use Cases

### Application Bucket
**Purpose**: Primary application data storage
- User uploads and generated content
- Application state and configuration
- Temporary processing files
- **Lifecycle**: 30d → IA → 90d → Glacier → 365d → Deep Archive
- **Retention**: Non-current versions kept for 90 days

### Backup Bucket
**Purpose**: Automated backup storage
- Database backups
- System snapshots
- Configuration backups
- **Lifecycle**: 1d → Glacier → 90d → Deep Archive
- **Retention**: Non-current versions kept for 30 days

### Logs Bucket
**Purpose**: Centralized logging and audit trails
- Application logs
- Access logs from other buckets
- CloudTrail logs
- VPC Flow Logs
- **Lifecycle**: 30d → IA → 90d → Glacier
- **Retention**: 7 years for compliance

### Static Assets Bucket
**Purpose**: CDN-ready static content
- Website assets (CSS, JS, images)
- Documentation files
- Public downloads
- **Lifecycle**: 90d → IA
- **Features**: Optional public read access, CORS support, website hosting

### Compliance Bucket
**Purpose**: Long-term compliance and audit storage
- Regulatory compliance data
- Financial records
- Legal documents
- **Lifecycle**: 90d → Glacier → 365d → Deep Archive
- **Retention**: Permanent (no expiration)

### Data Lake Bucket (Optional)
**Purpose**: Analytics and machine learning data
- Raw data ingestion
- Processed datasets
- ML training data
- **Lifecycle**: 90d → IA → 180d → Glacier
- **Features**: Optimized for analytics workloads

## Security Features

### Encryption
- **Server-Side Encryption**: Enabled by default
- **KMS Integration**: Optional customer-managed keys
- **Bucket Keys**: Enabled for cost optimization
- **In-Transit**: SSL/HTTPS required for all operations

### Access Control
- **Public Access Blocking**: Enabled by default on all buckets
- **Bucket Policies**: Deny insecure connections
- **IAM Integration**: Least-privilege access patterns
- **VPC Endpoints**: Private connectivity within VPC

### Compliance
- **Versioning**: Enabled for data protection
- **MFA Delete**: Optional for critical environments
- **Access Logging**: Comprehensive audit trails
- **Cross-Region Replication**: Disaster recovery compliance

## Cost Optimization

### Intelligent Tiering
Automatically moves objects between storage classes based on access patterns:
- **Frequent Access**: Standard storage
- **Infrequent Access**: Standard-IA (after 30 days)
- **Archive**: Glacier (after 90 days)
- **Deep Archive**: Long-term storage (after 365 days)

### Lifecycle Policies
Customized per bucket type:
```hcl
lifecycle_rules = {
  application = {
    enabled = true
    transitions = [
      { days = 30, storage_class = "STANDARD_IA" },
      { days = 90, storage_class = "GLACIER" },
      { days = 365, storage_class = "DEEP_ARCHIVE" }
    ]
    noncurrent_version_expiration_days = 90
  }
}
```

### Cost Monitoring
- **CloudWatch Metrics**: Monitor storage costs and usage
- **Inventory Reports**: Daily cost analysis data
- **Lifecycle Reporting**: Track transitions and savings

## Environment-Specific Configurations

### Development
```hcl
# Minimal features for cost savings
enable_cross_region_replication = false
enable_mfa_delete              = false
enable_inventory               = false
public_read_buckets           = []  # No public access
cors_origins                  = ["http://localhost:3000"]
```

### Staging
```hcl
# Moderate features for testing
enable_cross_region_replication = false
enable_mfa_delete              = false
enable_inventory               = false
enable_static_website          = true
cors_origins                   = ["https://staging.company.com"]
```

### Production
```hcl
# Full enterprise features
enable_cross_region_replication = true
enable_mfa_delete              = true
enable_inventory               = true
enable_static_website          = true
enable_event_notifications     = true
cors_origins                   = ["https://company.com"]
```

## Outputs

The module provides comprehensive outputs for integration:

```hcl
# Bucket Information
bucket_names                    # Map of bucket types to names
bucket_arns                    # Map of bucket types to ARNs
bucket_domain_names            # Map of bucket types to domain names

# Specific Bucket Access
application_bucket_name        # Direct access to application bucket
logs_bucket_arn               # Direct access to logs bucket ARN
static_assets_website_endpoint # Website endpoint for static assets

# Security Information
kms_key_id                    # KMS key used for encryption
kms_key_arn                   # KMS key ARN
replication_role_arn          # Cross-region replication role

# Configuration Summary
configuration_summary         # Complete configuration overview
security_features            # Applied security features
cost_optimization_features   # Enabled cost optimizations
```

## Integration Examples

### With CloudFront CDN
```hcl
resource "aws_cloudfront_distribution" "static_assets" {
  origin {
    domain_name = module.s3.bucket_domain_names["static-assets"]
    origin_id   = "s3-static-assets"
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.static_assets.cloudfront_access_identity_path
    }
  }
  
  default_cache_behavior {
    target_origin_id = "s3-static-assets"
    # ... other configuration
  }
}
```

### With Lambda for Processing
```hcl
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3.application_bucket_arn
}

resource "aws_s3_bucket_notification" "application_bucket" {
  bucket = module.s3.application_bucket_name
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }
}
```

### With Backup Integration
```hcl
resource "aws_backup_plan" "main" {
  name = "${var.project_name}-backup-plan"
  
  rule {
    rule_name         = "daily_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)"
    
    recovery_point_tags = {
      BackupType = "automated"
    }
    
    lifecycle {
      cold_storage_after = 30
      delete_after      = 120
    }
  }
}
```

## Best Practices

### Security
1. **Never enable public access unless absolutely necessary**
2. **Always use encryption in production**
3. **Enable MFA delete for critical buckets**
4. **Monitor access patterns and costs regularly**
5. **Use VPC endpoints to keep traffic within AWS**

### Performance
1. **Use intelligent tiering for unknown access patterns**
2. **Implement proper CORS policies for web applications**
3. **Use CloudFront for global content distribution**
4. **Monitor and optimize request patterns**

### Cost Management
1. **Review lifecycle policies regularly**
2. **Monitor storage class distributions**
3. **Use inventory reports for cost analysis**
4. **Consider requester pays for external access**

### Compliance
1. **Enable access logging for audit trails**
2. **Implement proper retention policies**
3. **Use cross-region replication for critical data**
4. **Regular compliance audits and reviews**

## Troubleshooting

### Common Issues

1. **Cross-region replication not working**
   - Ensure versioning is enabled on both source and destination
   - Check IAM role permissions
   - Verify destination bucket exists and is accessible

2. **Public access blocked unexpectedly**
   - Check `public_read_buckets` configuration
   - Verify bucket policy dependencies
   - Review account-level public access settings

3. **Lifecycle policies not applying**
   - Verify lifecycle rules are enabled
   - Check object size and age requirements
   - Monitor transition status in CloudWatch

4. **High costs**
   - Review storage class distributions
   - Check request patterns and optimize
   - Evaluate lifecycle policy effectiveness

### Monitoring Commands

```bash
# Check bucket sizes
aws s3api list-objects-v2 --bucket BUCKET_NAME --query 'sum(Contents[].Size)'

# Monitor lifecycle transitions
aws logs filter-log-events --log-group-name /aws/s3/lifecycle

# Review access patterns
aws s3api get-bucket-metrics-configuration --bucket BUCKET_NAME
```

## Requirements

- Terraform >= 1.5.0
- AWS Provider >= 5.0
- Appropriate AWS permissions for S3, KMS, and IAM resources

## License

This module is part of the enterprise infrastructure toolkit and follows organizational licensing terms.
