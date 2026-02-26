# 🚀 Cloudflare DNS Migration Quick Start Guide

This guide will help you quickly set up Cloudflare DNS and CDN integration for **diatonic.ai** using our unified Terraform configuration.

## 📋 Prerequisites Checklist

- [ ] **Cloudflare Account**: Domain `diatonic.ai` added to your Cloudflare dashboard
- [ ] **API Token**: Cloudflare API token with `Zone:Edit` permissions
- [ ] **Tools**: Terraform >= 1.5.0, AWS CLI, `jq`, `curl` installed
- [ ] **AWS Access**: Valid AWS credentials configured (`aws sts get-caller-identity` works)

## 🎯 Quick Setup (5 Minutes)

### Step 1: Get Your Cloudflare API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **"Create Token"**
3. Use **"Edit zone DNS"** template
4. Select Zone: `diatonic.ai`
5. Copy the generated token

### Step 2: Run the Setup Script

```bash
cd /home/daclab-ai/dev/AWS-DevOps/unified-terraform

# Method 1: Interactive setup (will prompt for token)
./setup-cloudflare.sh init apply

# Method 2: Direct with token
./setup-cloudflare.sh --token "YOUR_TOKEN_HERE" init apply

# Method 3: Dry run first (recommended)
./setup-cloudflare.sh --token "YOUR_TOKEN_HERE" --dry-run apply
```

### Step 3: Verify Configuration

```bash
# Check status
./setup-cloudflare.sh status

# Show migration instructions
./setup-cloudflare.sh migrate
```

## 🔧 Advanced Usage

### Environment-Specific Deployment

```bash
# Production environment
./setup-cloudflare.sh --token "TOKEN" --env prod apply

# Staging environment  
./setup-cloudflare.sh --token "TOKEN" --env staging apply
```

### Terraform Commands (Manual)

If you prefer to use Terraform directly:

```bash
# Set environment variables
export CLOUDFLARE_API_TOKEN="your_token_here"
export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"

# Initialize and plan
terraform init
terraform workspace new cloudflare
terraform plan -var-file="terraform.tfvars"

# Apply changes
terraform apply -var-file="terraform.tfvars"
```

## 📊 What Gets Created

The setup script will create:

### DNS Records
- **A Record**: `diatonic.ai` → `d34iz6fjitwuax.cloudfront.net` (proxied)
- **CNAME Records**: All subdomains (www, api, app, etc.) → CloudFront
- **MX Records**: Email routing (if configured)
- **TXT Records**: Domain verification and SPF

### Security & Performance
- **SSL/TLS**: Full (strict) mode with automatic HTTPS redirects
- **Security Level**: Medium with bot fight mode enabled
- **Rate Limiting**: 100 requests per minute per IP
- **Firewall Rules**: Basic protection against common threats
- **Page Rules**: Caching optimization for static assets

### Monitoring
- **Analytics**: Traffic and performance metrics
- **Alerts**: SSL certificate and DNS monitoring
- **Logs**: Security events and traffic patterns

## 🎛️ Configuration Options

Edit `terraform.tfvars` for customization:

```hcl
# Enable/disable features
enable_cloudflare = true
enable_bot_protection = true
enable_rate_limiting = true
enable_ssl_redirect = true

# Custom domains
additional_domains = ["api.diatonic.ai", "app.diatonic.ai"]

# Email for alerts
notification_email = "admin@diatonic.ai"

# Security settings
security_level = "medium"  # low, medium, high, under_attack
ssl_mode = "full_strict"   # off, flexible, full, full_strict
```

## 🔄 DNS Migration Process

After Terraform applies successfully:

### 1. **Verify DNS Records** ✅
```bash
# Check new DNS records
dig @adina.ns.cloudflare.com diatonic.ai A
dig @adina.ns.cloudflare.com www.diatonic.ai CNAME
```

### 2. **Update Domain Nameservers** 🔄
In your domain registrar (e.g., Namecheap, GoDaddy):
- Current: Route 53 nameservers
- **Change to**: Cloudflare nameservers (shown in output)

### 3. **Wait for Propagation** ⏱️
- DNS propagation: 2-48 hours
- SSL provisioning: 5-15 minutes after propagation

### 4. **Test & Verify** 🧪
```bash
# Test from different locations
curl -I https://diatonic.ai
curl -I https://www.diatonic.ai
curl -I https://api.diatonic.ai

# Check SSL
openssl s_client -connect diatonic.ai:443 -servername diatonic.ai
```

### 5. **Monitor Dashboard** 📊
Visit [Cloudflare Dashboard](https://dash.cloudflare.com/2ce1478eaf8042eaa3bee715d34301b9)

## 🚨 Troubleshooting

### Common Issues

**Invalid API Token**
```bash
# Test your token
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://api.cloudflare.com/client/v4/user/tokens/verify"
```

**Terraform Plan Errors**
```bash
# Refresh state
terraform refresh -var-file="terraform.tfvars"

# Check workspace
terraform workspace show
terraform workspace list
```

**DNS Not Resolving**
```bash
# Check propagation status
./cloudflare-automation.sh test_dns_propagation

# Force DNS flush (local)
sudo systemctl flush-dns  # Linux
sudo dscacheutil -flushcache  # macOS
```

### Script Help
```bash
# Show all available options
./setup-cloudflare.sh --help

# Check current status
./setup-cloudflare.sh status

# View migration instructions
./setup-cloudflare.sh migrate
```

## 📚 Additional Resources

| Resource | Description | Link |
|----------|-------------|------|
| **Migration Guide** | Detailed migration process | [cloudflare-dns-migration.md](./cloudflare-dns-migration.md) |
| **Automation Script** | Manual DNS management | [cloudflare-automation.sh](./cloudflare-automation.sh) |
| **Terraform Module** | Cloudflare Terraform config | [modules/cloudflare/](./modules/cloudflare/) |
| **Cloudflare Dashboard** | Zone management | [dash.cloudflare.com](https://dash.cloudflare.com/f889715fdbadcf662ea496b8e40ee6eb) |
| **Analytics** | Traffic & performance | [analytics](https://dash.cloudflare.com/f889715fdbadcf662ea496b8e40ee6eb/analytics) |

## ⚡ Quick Commands Reference

```bash
# Complete setup (one command)
./setup-cloudflare.sh --token "TOKEN" init apply

# Status check
./setup-cloudflare.sh status

# Plan only (dry run)
./setup-cloudflare.sh --token "TOKEN" plan

# Force apply without prompts
./setup-cloudflare.sh --token "TOKEN" --force apply

# Clean up (remove everything)
./setup-cloudflare.sh --token "TOKEN" destroy

# Show migration steps
./setup-cloudflare.sh migrate
```

## 🎉 Success Indicators

You'll know the setup is successful when:

- ✅ Terraform apply completes without errors
- ✅ DNS records are visible in Cloudflare dashboard
- ✅ SSL certificate shows "Active" status
- ✅ `curl -I https://diatonic.ai` returns Cloudflare headers
- ✅ Page load times improve (check analytics after 24h)

## 📞 Support

If you encounter issues:

1. **Check logs**: `terraform show` and script output
2. **Verify prerequisites**: API token, AWS credentials, tools
3. **Review configuration**: `terraform.tfvars` settings
4. **Test manually**: Use `cloudflare-automation.sh` for debugging

---

**🔗 Ready to start?** Run `./setup-cloudflare.sh --help` to see all available options!
