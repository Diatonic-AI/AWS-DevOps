# Diatonic AI Production Configuration Guide

## 🚀 **Recommended Production Configuration for diatonic.ai**

### **Overview**
This guide outlines the optimal production configuration for your Diatonic AI web application infrastructure on AWS. The configuration is designed for scalability, security, and cost-effectiveness.

## 📊 **Architecture Summary**

### **Core Infrastructure Components**
- **VPC**: Production-grade network with 3 AZs (10.0.0.0/16)
- **ECS Fargate**: Containerized application hosting
- **Application Load Balancer**: High-availability load distribution
- **CloudFront CDN**: Global content delivery network
- **Route53 DNS**: Domain name management
- **S3**: Static asset storage with enterprise features
- **Security**: GuardDuty, Config, Security Hub enabled

### **Domain Strategy**
- **Primary Domain**: `diatonic.ai`
- **Application**: `app.diatonic.ai`
- **Administration**: `admin.diatonic.ai`
- **API Endpoints**: `api.diatonic.ai`

## 🔧 **Key Configuration Recommendations**

### 1. **ECS Fargate Configuration**
```hcl
# Optimized for production performance
ecs_cpu    = 512   # 0.5 vCPU
ecs_memory = 1024  # 1 GB RAM

# High availability scaling
min_capacity = 2   # Always maintain 2 instances
max_capacity = 10  # Scale up to 10 for traffic spikes
desired_capacity = 3  # Start with 3 instances
target_cpu_utilization = 60%  # Scale trigger
```

### 2. **CloudFront CDN Configuration**
```hcl
# Better global performance
price_class = "PriceClass_200"  # US, Canada, Europe, Asia

# Caching strategy
default_ttl = 86400  # 1 day for dynamic content
max_ttl = 31536000   # 1 year for static assets
min_ttl = 0          # No minimum caching
```

### 3. **Security Configuration**
```hcl
# Enhanced security features
enable_security_features = true
enable_guardduty = true
enable_config = true
enable_security_hub = true
force_ssl_redirect = true
minimum_protocol_version = "TLSv1.2_2021"
```

### 4. **Monitoring & Alerting**
```hcl
# Production monitoring
enable_detailed_monitoring = true
cpu_alarm_threshold = 80%
memory_alarm_threshold = 80%
response_time_threshold = 2000ms
error_rate_threshold = 5%
log_retention_days = 30
```

## 💰 **Cost Optimization Features**

### **Enabled Cost Optimizations**
- **Auto Scaling**: Automatic scaling based on CPU utilization
- **Scheduled Scaling**: Scale down at 2 AM, up at 8 AM UTC
- **Single NAT Gateway**: For non-production environments
- **VPC Endpoints**: Reduce NAT Gateway costs for AWS services
- **CloudFront Caching**: Reduce origin requests
- **S3 Intelligent Tiering**: Automatic storage cost optimization

### **Estimated Monthly Costs** (Starting Configuration)
- **ECS Fargate** (2-3 instances): ~$35-50/month
- **Application Load Balancer**: ~$20/month
- **CloudFront**: ~$10-30/month (depending on traffic)
- **Route53**: ~$0.50/month per hosted zone
- **S3 Storage**: ~$5-20/month (depending on content)
- **NAT Gateway**: ~$32/month (production) or ~$32/month (dev/staging)
- **Total Estimated**: ~$100-150/month for moderate traffic

## 🔐 **Security Recommendations**

### **Immediate Security Setup**
1. **Enable notification email** for security alerts
2. **Configure allowed_cidr_blocks** for restricted access
3. **Set up ACM certificates** for SSL/TLS
4. **Review IAM permissions** for least privilege access
5. **Enable AWS CloudTrail** for audit logging

### **Optional Security Enhancements**
- **AWS WAF**: Can be enabled later for application-level protection
- **GuardDuty**: Already enabled for threat detection
- **Security Hub**: Centralized security findings
- **Config Rules**: Compliance monitoring

## 🌐 **Domain Setup Requirements**

### **Pre-Deployment Checklist**
1. **Domain Registration**: Ensure `diatonic.ai` is registered
2. **DNS Management**: Decide on Route53 vs external DNS provider
3. **SSL Certificates**: Request ACM certificates for all domains
4. **Email Setup**: Configure notification email for alerts

### **Subdomain Strategy**
```
diatonic.ai              -> Main website/landing page
app.diatonic.ai         -> Web application
admin.diatonic.ai       -> Administrative interface
api.diatonic.ai         -> API endpoints
static.diatonic.ai      -> Static assets (optional)
```

## 📈 **Scaling Strategy**

### **Phase 1: Initial Launch**
- Start with homepage on S3 + CloudFront
- Basic ECS application for dynamic content
- 2-3 ECS tasks for availability

### **Phase 2: Growth**
- Enable database when needed
- Increase max_capacity for scaling
- Add caching layer (ElastiCache)
- Consider multi-region deployment

### **Phase 3: Scale**
- Enable Origin Shield on CloudFront
- Consider ECS Service Connect for microservices
- Implement auto-scaling policies
- Add monitoring and observability

## 🔄 **Deployment Strategy**

### **Recommended Deployment Flow**
1. **Deploy Core Infrastructure** (VPC, S3, basic security)
2. **Deploy Web Application** (ECS, ALB, basic CloudFront)
3. **Configure DNS** (Route53 or external DNS)
4. **Set up SSL Certificates** (ACM)
5. **Enable Monitoring** (CloudWatch, alerts)
6. **Performance Testing** and optimization

### **Environment Progression**
- **Development**: Single AZ, minimal resources
- **Staging**: Production-like for testing
- **Production**: Full configuration with high availability

## 📝 **Next Steps**

### **Immediate Actions**
1. Review and customize the configuration variables
2. Set up AWS credentials and profiles
3. Initialize Terraform backend state
4. Run `terraform plan` to review resources
5. Deploy infrastructure incrementally

### **Post-Deployment**
1. Configure domain DNS records
2. Set up monitoring dashboards
3. Implement backup strategies
4. Create disaster recovery plan
5. Document operational procedures

## ⚡ **Quick Start Commands**

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan -var-file="terraform.prod.tfvars"

# Deploy infrastructure
terraform apply -var-file="terraform.prod.tfvars"

# Check outputs
terraform output
```

## 📞 **Support & Maintenance**

### **Regular Maintenance Tasks**
- Review and update security patches
- Monitor cost optimization opportunities
- Review scaling metrics and adjust thresholds
- Update SSL certificates before expiration
- Regular backup verification

### **Monitoring Dashboards**
- ECS service health and scaling metrics
- ALB response times and error rates
- CloudFront cache hit ratios and performance
- S3 storage usage and costs
- Security findings and alerts

---

**Note**: This configuration is optimized for a startup/small business environment with growth potential. Adjust resources based on your specific traffic patterns and requirements.
