# 🔑 Using Global API Key with Setup Script

## What We Have
- ✅ **Global API Key**: `1063cb0eb2f2cd9f9778d17712bdff9b1d11f`
- ✅ **Zone ID**: `f889715fdbadcf662ea496b8e40ee6eb`
- ✅ **Account ID**: `35043351f8c199237f5ebd11f4a27c15`
- ❓ **Email**: *[NEEDED - Your Cloudflare account email]*

## How to Run Once We Have Your Email

### Method 1: Export Environment Variables
```bash
cd /home/daclab-ai/dev/AWS-DevOps/unified-terraform

# Set your credentials
export CLOUDFLARE_API_KEY="1063cb0eb2f2cd9f9778d17712bdff9b1d11f"
export CLOUDFLARE_EMAIL="your-email@example.com"  # Replace with your actual email

# Run the setup
./setup-cloudflare.sh init apply
```

### Method 2: Direct Command Line
```bash
# All in one command
CLOUDFLARE_API_KEY="1063cb0eb2f2cd9f9778d17712bdff9b1d11f" \
CLOUDFLARE_EMAIL="your-email@example.com" \
./setup-cloudflare.sh init apply
```

### Method 3: Interactive (will prompt for email)
```bash
# The script will detect you're using API Key and ask for email
CLOUDFLARE_API_KEY="1063cb0eb2f2cd9f9778d17712bdff9b1d11f" \
./setup-cloudflare.sh init apply
```

## Test Authentication First
```bash
# Test with your actual email
curl -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "X-Auth-Email: your-email@example.com" \
  -H "X-Auth-Key: 1063cb0eb2f2cd9f9778d17712bdff9b1d11f" | jq .

# Should return success: true
```

## What Will Be Created
Once we have valid authentication:

1. **DNS Records**:
   - A record: `diatonic.ai` → CloudFront
   - CNAME: `www.diatonic.ai` → CloudFront  
   - CNAME: `api.diatonic.ai` → CloudFront
   - CNAME: `app.diatonic.ai` → CloudFront

2. **SSL/TLS Settings**:
   - Full (strict) SSL mode
   - Always use HTTPS
   - Minimum TLS version 1.2

3. **Performance Settings**:
   - Caching rules for static assets
   - Page rules for optimization
   - Compression enabled

4. **Security Settings**:
   - Bot fight mode
   - Rate limiting (100 req/min)
   - Basic firewall rules

## 🚨 Security Notes

- Your API key is handled securely via environment variables
- It's never stored in files or Terraform state
- The script validates the credentials before proceeding
- All operations are logged for audit purposes

## Next Steps

**Please provide your Cloudflare account email**, then we can:
1. Test the authentication
2. Run a dry-run to show what will be created
3. Apply the configuration
4. Update your domain nameservers for migration

---

**Ready to proceed once we have your email address!**
