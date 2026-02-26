# 🚀 Quick Cloudflare + AWS Setup Guide

## **5-Minute Setup for Your Domain Integration**

Follow these steps to connect your Cloudflare domain to your AWS web application:

---

## **Step 1: Set Your Domain in Terraform** ⚙️

Update your development configuration:

```bash
# Edit your terraform variables
nano /home/daclab-work001/DEV/AWS-DevOps/infrastructure/terraform/core/terraform.dev.tfvars
```

Add your domain:
```terraform
# Add this line to terraform.dev.tfvars:
web_app_domain_name = "dev.yourdomain.com"  # Replace with your actual domain
```

---

## **Step 2: Deploy Your AWS Infrastructure** 🏗️

```bash
# Navigate to terraform directory
cd /home/daclab-work001/DEV/AWS-DevOps/infrastructure/terraform

# Deploy your infrastructure
./deploy.sh dev apply

# Get your Load Balancer DNS name (you'll need this for Cloudflare)
terraform output web_application_load_balancer_dns
```

**Copy the Load Balancer DNS name** - it will look like:
`aws-devops-dev-alb-1234567890.us-east-2.elb.amazonaws.com`

---

## **Step 3: Configure Cloudflare DNS** ☁️

1. **Login to Cloudflare Dashboard**
2. **Select Your Domain**
3. **Go to DNS → Records**
4. **Add a CNAME Record**:

```
Type: CNAME
Name: dev (or whatever subdomain you want)
Target: aws-devops-dev-alb-1234567890.us-east-2.elb.amazonaws.com
Proxy status: 🟠 Proxied (orange cloud ON for CDN benefits)
TTL: Auto
```

---

## **Step 4: Configure Cloudflare SSL** 🔒

1. **Go to SSL/TLS → Overview**
2. **Set SSL mode to "Full"** (or "Full (strict)" if you have valid certs on AWS)
3. **Enable "Always Use HTTPS"**
4. **Go to SSL/TLS → Edge Certificates**
5. **Enable "Automatic HTTPS Rewrites"**

---

## **Step 5: Test Your Setup** ✅

Wait 2-3 minutes for DNS propagation, then test:

```bash
# Test DNS resolution
nslookup dev.yourdomain.com

# Test SSL and application
curl -I https://dev.yourdomain.com

# Visit in browser
open https://dev.yourdomain.com
```

You should see your beautiful homepage! 🎉

---

## **Optional: Performance Optimization** ⚡

### **Speed Settings (Cloudflare Dashboard)**
1. **Go to Speed → Optimization**
2. **Enable these features**:
   - ✅ Auto Minify (JS, CSS, HTML)
   - ✅ Brotli compression  
   - ✅ Early Hints
   - ✅ Image Optimization

### **Caching Rules**
1. **Go to Rules → Page Rules** (if on paid plan)
2. **Create rule for API paths**:
   ```
   URL: dev.yourdomain.com/api/*
   Settings: Cache Level = Bypass
   ```
3. **Create rule for static assets**:
   ```
   URL: dev.yourdomain.com/static/*
   Settings: Cache Level = Cache Everything, Edge Cache TTL = 1 month
   ```

---

## **Multi-Environment Setup** 🚀

For staging and production:

### **Staging Environment**
```bash
# Deploy staging
./deploy.sh staging apply

# In Cloudflare, add:
Type: CNAME
Name: staging  
Target: [staging-alb-dns-name]
Proxy: 🟠 Proxied
```

### **Production Environment**
```bash
# Deploy production
./deploy.sh prod apply  

# In Cloudflare, add:
Type: CNAME
Name: @ (root domain)
Target: [prod-alb-dns-name]  
Proxy: 🟠 Proxied

# Or for www:
Type: CNAME
Name: www
Target: [prod-alb-dns-name]
Proxy: 🟠 Proxied
```

---

## **Benefits You'll Get** 💰

- ✅ **Free CDN** - Global content delivery
- ✅ **Free SSL** - Automatic certificate management
- ✅ **DDoS Protection** - Industry-leading security
- ✅ **Cost Savings** - $50-3000/month vs AWS-only
- ✅ **Better Performance** - 250+ edge locations
- ✅ **Advanced Analytics** - Traffic insights and security events

---

## **Troubleshooting** 🔧

### **Issue: Site not loading**
- Wait 5 minutes for DNS propagation
- Check CNAME record points to correct ALB DNS name
- Verify ALB is running: `aws elbv2 describe-load-balancers`

### **Issue: SSL errors**
- Set Cloudflare SSL mode to "Full" (not "Strict")
- Ensure "Always Use HTTPS" is enabled
- Check ALB health checks are passing

### **Issue: 502 errors**  
- Verify ECS tasks are running and healthy
- Check ALB target group health
- Review CloudWatch logs: `/aws/ecs/your-cluster-name`

### **Get Help**
```bash
# Check AWS resources
terraform output -json | jq '.'

# Check ECS service
aws ecs describe-services --cluster aws-devops-dev-cluster --services aws-devops-dev-service

# Check ALB health
aws elbv2 describe-target-health --target-group-arn [your-target-group-arn]
```

---

## **What's Your Domain?** 🌐

Once you tell me your domain name, I can provide specific DNS record configurations and help you set up the exact CNAME records you need!

**Example Setup:**
- **Your domain**: `example.com`
- **Development**: `dev.example.com` → AWS ALB
- **Staging**: `staging.example.com` → AWS ALB  
- **Production**: `example.com` → AWS ALB

---

**🎯 Ready to connect your domain? Just update the terraform variable with your domain name and follow the steps above!**
