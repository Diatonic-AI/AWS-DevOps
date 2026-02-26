# Client Billing Portal - Quick Start Guide

## 🚀 Get Your First Client Paying in 3 Steps

### Step 1: Set Up Stripe (5 minutes)

1. **Create Stripe account:** https://stripe.com (if you don't have one)

2. **Get your API keys:**
   - Go to Stripe Dashboard → Developers → API keys
   - Copy your "Secret key" (starts with `sk_live_...` for production or `sk_test_...` for testing)

3. **Save to AWS:**
   ```bash
   aws secretsmanager create-secret \
       --name client-billing/stripe-api-key \
       --secret-string '{"apiKey":"sk_test_YOUR_KEY_HERE"}' \
       --region us-east-1
   ```

### Step 2: Deploy the Portal (10 minutes)

```bash
# Navigate to AWS-DevOps directory
cd /home/daclab-ai/DEV/AWS-DevOps

# Run deployment script
chmod +x scripts/deploy-client-billing-portal.sh
./scripts/deploy-client-billing-portal.sh
```

This will create:
- ✅ 2 Lambda functions
- ✅ API Gateway with your endpoints
- ✅ DynamoDB table
- ✅ Client portal ready to deploy

**SAVE THE API URL** - You'll need it!

### Step 3: Host the Portal (5 minutes)

**Easiest Option - S3 Static Website:**

```bash
# Create bucket
aws s3 mb s3://mmp-toledo-billing-portal --region us-east-1

# Enable website hosting
aws s3 website s3://mmp-toledo-billing-portal \
    --index-document index.html

# Make public
aws s3api put-bucket-policy --bucket mmp-toledo-billing-portal --policy '{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicReadGetObject",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::mmp-toledo-billing-portal/*"
  }]
}'

# Upload portal
aws s3 sync client-portal/public/ s3://mmp-toledo-billing-portal/

# Access at:
# http://mmp-toledo-billing-portal.s3-website-us-east-1.amazonaws.com
```

## 📧 Send to Your Client

```
Subject: Your New AWS Billing Portal is Ready!

Hi [Client Name],

Great news! Your AWS billing portal is now live. You can now:
• View your AWS costs in real-time
• See detailed breakdowns by service
• Add your credit card for automatic monthly billing

Access your portal here:
http://mmp-toledo-billing-portal.s3-website-us-east-1.amazonaws.com

To set up automatic billing:
1. Click the green "Add Payment Method" button
2. Securely enter your credit card (powered by Stripe - we never see your card details)
3. That's it! We'll automatically bill you monthly

Your current month's cost is already displayed in the portal.

Questions? Just reply to this email!

Best,
[Your Name]
```

## ✅ Testing Before Sending to Client

1. **Test the costs API:**
   ```bash
   curl "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/costs?clientOrganization=MMP-Toledo&period=current-month"
   ```

2. **Open the portal in your browser:**
   - Should see current costs (may be $0 if cost allocation tags just activated)
   - Charts should load
   - "Add Payment Method" button should work

3. **Test payment flow:**
   - Click "Add Payment Method"
   - Use Stripe test card: `4242 4242 4242 4242`
   - Any future expiry date, any CVV
   - Should redirect back with success message

## 🔄 Automated Monthly Billing

Once payment method is added, costs are automatically charged monthly.

**Manual invoice for testing:**

```bash
# Get last month's total from portal
# Then create invoice:
curl -X POST "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/payment" \
    -H "Content-Type: application/json" \
    -d '{
        "action": "create-invoice",
        "clientId": "mmp-toledo",
        "clientName": "Minute Man Press Toledo",
        "email": "aws+minute-man-press@dacvisuals.com",
        "billingPeriod": "2025-12",
        "amount": 125.50
    }'
```

This sends an invoice email to the client with a pay link.

## 📊 Adding More Clients

For each new client:

1. **Tag their resources** (use existing tagging scripts):
   ```bash
   # Modify tag-mmp-toledo-resources.sh for new client
   # Change CLIENT_ORG, CLIENT_NAME, etc.
   ./scripts/tag-new-client-resources.sh
   ```

2. **Create their portal** - Copy `index.html` and update:
   ```javascript
   const CLIENT_ORG = 'New-Client-Name';
   const CLIENT_ID = 'new-client-id';
   const CLIENT_NAME = 'New Client Business Name';
   const CLIENT_EMAIL = 'client@example.com';
   ```

3. **Deploy to unique URL:**
   ```bash
   aws s3 mb s3://new-client-billing-portal --region us-east-1
   aws s3 website s3://new-client-billing-portal --index-document index.html
   aws s3 sync client-portal-new-client/ s3://new-client-billing-portal/
   ```

## 🆘 Troubleshooting

### "No costs showing"
- Cost allocation tags take 24 hours to activate
- Check resources are tagged with `ClientOrganization=MMP-Toledo`
- Verify tags in Cost Explorer console

### "Payment method won't add"
- Check Stripe API key in Secrets Manager
- View Lambda logs: `aws logs tail /aws/lambda/client-billing-payment --follow`
- Make sure Stripe account is activated

### "API not responding"
- Check API Gateway URL is correct in index.html
- Test API directly with curl
- Check Lambda permissions for Cost Explorer access

## 💰 Pricing for Clients

**Recommended markup:**

| Client's AWS Usage | Your Monthly Fee |
|-------------------|------------------|
| $0 - $100 | $10 flat fee |
| $100 - $500 | $25 flat fee |
| $500+ | 10% of AWS costs |

**Alternative:** Include in your existing managed services fee.

## 📚 Full Documentation

- **Complete Guide:** `/home/daclab-ai/DEV/AWS-DevOps/docs/CLIENT-BILLING-PORTAL.md`
- **Deployment Details:** `CLIENT-BILLING-PORTAL-DEPLOYMENT.md`
- **Resource Assignment:** `MMP-Toledo-Resource-Assignment-Report.md`

## 🎯 Next Steps

1. ✅ Deploy portal for MMP Toledo
2. ✅ Send them the welcome email
3. ⏳ Wait 24 hours for cost data to populate
4. ✅ Test payment flow
5. ✅ Set up monthly billing automation
6. 🚀 Add more clients!

---

**Need Help?**
- Check CloudWatch Logs for errors
- Review `/docs/CLIENT-BILLING-PORTAL.md`
- Contact: aws@dacvisuals.com

**Portal Infrastructure Cost:** ~$4-5/month per client
**Time to Set Up First Client:** ~20 minutes
**Time to Add Additional Clients:** ~5 minutes each
