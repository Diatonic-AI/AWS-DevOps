# 🔑 Cloudflare API Token Setup Guide

## Current Issue
The API token provided appears to be invalid or incomplete. Let's create a proper Cloudflare API token.

## ✅ Step-by-Step Token Creation

### 1. Go to Cloudflare API Tokens Page
Visit: https://dash.cloudflare.com/profile/api-tokens

### 2. Create a Custom Token
1. Click **"Create Token"**
2. Choose **"Custom token"** (not "Edit zone DNS" template)
3. Configure the token with these settings:

#### Token Settings
```
Token name: Terraform-AWS-DevOps-DNS
```

#### Permissions
```
Zone:Zone:Read
Zone:DNS:Edit  
Zone:Zone Settings:Edit
Zone:Page Rules:Edit
```

#### Zone Resources
```
Include: Specific zone - diatonic.ai
```

#### Client IP Address Filtering (Optional)
```
Leave blank or add your current IP if you want extra security
```

#### TTL (Optional)
```
Leave blank for no expiration, or set a reasonable time like 1 year
```

### 3. Test Your New Token

Once you get the token, test it:

```bash
# Replace YOUR_TOKEN_HERE with your actual token
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type:application/json"
```

**Expected successful response:**
```json
{
  "success": true,
  "errors": [],
  "messages": [],
  "result": {
    "id": "...",
    "status": "active"
  }
}
```

## 🔄 Alternative: Using Global API Key

If you prefer to use your Global API Key instead:

### Get Global API Key
1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Scroll down to **"API Keys"**
3. Find **"Global API Key"** and click **"View"**

### Test Global API Key
```bash
# Replace with your actual email and global API key
curl -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "X-Auth-Email: your-email@example.com" \
  -H "X-Auth-Key: your-global-api-key"
```

## 🚀 Once You Have a Valid Token

Run the setup again:

```bash
cd /home/daclab-ai/dev/AWS-DevOps/unified-terraform

# Method 1: Interactive (will prompt for token)
./setup-cloudflare.sh init apply

# Method 2: Direct with token
export CLOUDFLARE_API_TOKEN="your-new-token-here"
./setup-cloudflare.sh init apply

# Method 3: Test first with dry-run
export CLOUDFLARE_API_TOKEN="your-new-token-here"
./setup-cloudflare.sh --dry-run apply
```

## 🔍 Troubleshooting

### Common Issues

1. **"Invalid request headers"**
   - Token format is wrong
   - Using API Key instead of API Token
   - Token has expired

2. **"Insufficient permissions"**
   - Token doesn't have Zone:DNS:Edit permission
   - Token isn't associated with the correct zone

3. **"Zone not found"**
   - Zone ID is incorrect
   - Token doesn't have access to the zone

### Verify Your Current Credentials
Your provided credentials:
- ✅ **Zone ID**: `f889715fdbadcf662ea496b8e40ee6eb` (looks correct)
- ✅ **Account ID**: `35043351f8c199237f5ebd11f4a27c15` (looks correct)
- ❌ **API Token**: `1063cb0eb2f2cd9f9778d17712bdff9b1d11f` (invalid format)

## 📞 Next Steps

1. **Create a new API token** following the steps above
2. **Test the token** using the curl command
3. **Run the setup script** with the new token
4. **Provide the new token** and I'll help you continue with the deployment

---

**Need Help?** Let me know once you have a valid API token and I'll continue with the Cloudflare DNS migration!
