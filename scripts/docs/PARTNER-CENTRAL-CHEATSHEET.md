# Partner Central Quick Reference Card

**Keep this open while completing tasks**

---

## 🔑 IAM Role ARNs (Copy-Paste Ready)

```
arn:aws:iam::313476888312:role/AWSPartnerCentralAccess
arn:aws:iam::313476888312:role/AWSPartnerACEAccess
arn:aws:iam::313476888312:role/AWSPartnerAllianceAccess
```

---

## ✅ Task Completion Commands

```bash
# Mark task as done:
./scripts/partner-tasks-tracker.sh complete 3
./scripts/partner-tasks-tracker.sh complete 4
./scripts/partner-tasks-tracker.sh complete 5
./scripts/partner-tasks-tracker.sh complete 12
./scripts/partner-tasks-tracker.sh complete 15

# Check progress:
./scripts/partner-tasks-tracker.sh
```

---

## 🔗 Quick Links

- **Partner Central**: https://partnercentral.aws.amazon.com/
- **Marketplace Management**: https://aws.amazon.com/marketplace/management/
- **AWS Console**: https://console.aws.amazon.com/

---

## 📋 Task Checklist

### HIGH PRIORITY (Do First):
- [ ] Task 3: Map Alliance Team → Settings > Team Management > Alliance Team
- [ ] Task 4: Map ACE Users → Settings > Team Management > ACE Users
- [ ] Task 5: Assign User Role → Settings > Users > Drew Fortini > Edit
- [ ] Task 15: Assign Cloud Admin → Settings > Team Management > Assign Cloud Admin
- [ ] Task 12: Invite Users → Settings > Users > Invite User

### MEDIUM PRIORITY (Do Next):
- [ ] Task 8: Pay APN Fee ($2,500 Select tier) → Settings > Membership
- [ ] Task 14: Build Software Solution → Solutions > Create Solution
- [ ] Task 1: Schedule Migration → Migration widget

### LOW PRIORITY (Optional):
- [ ] Task 2: Create PO Opportunity
- [ ] Task 7: AWS Marketplace Listing
- [ ] Task 9: Build Managed Services
- [ ] Task 10-13: Update Company Profile
- [ ] Task 16: Learn Marketplace
- [ ] Task 17: Build Services Solution

---

## 🏗️ Task 14: Build Software Solution (AI Nexus Workbench)

**Quick Details:**
```
Name: Diatonic AI Nexus Workbench
Category: AI/ML, Container Management
Builder Account: 916873234430
AWS Services: ECR, ECS, Lambda, API Gateway, DynamoDB, Cognito, S3

Description:
Comprehensive AI/ML workbench platform built on AWS serverless
technologies. Provides secure, scalable infrastructure for AI model
development, training, and deployment.

Files to Reference:
- apps/diatonic-ai-workbench/ (application)
- infrastructure/terraform/core/ (IaC templates)
```

---

## 💳 Task 8: APN Membership Tiers

| Tier | Annual Cost | Recommendation |
|------|-------------|----------------|
| Registered | FREE | Basic access only |
| **Select** | **$2,500** | ⭐ **RECOMMENDED** |
| Advanced | $15,000 | Full benefits |

**Select Tier Benefits:**
- AWS Marketplace eligibility
- Co-marketing support
- Partner training
- Qualified leads

---

## 🆘 Troubleshooting

**Can't find IAM Roles option?**
- Check you're logged in as admin
- Try Settings > Account Management

**Role ARN not accepted?**
- Verify you copied the full ARN (starts with `arn:aws:iam::`)
- Check for extra spaces or line breaks

**User not found?**
- May need to invite user first (Task 12)
- Check user email matches Partner Central account

---

## 📞 Support

**AWS Partner Central Support:**
https://support.console.aws.amazon.com/support/home

**Partner Network Help:**
https://aws.amazon.com/partners/

---

## ⏱️ Time Estimates

- High Priority Tasks: **50-60 min**
- Medium Priority Tasks: **2-3 hours**
- Low Priority Tasks: **1-2 hours**
- **Total**: **4-6 hours**

---

## 🎯 Success Metrics

**After High Priority Tasks:**
- [ ] Alliance team can access Partner Central
- [ ] ACE users have appropriate permissions
- [ ] You're assigned as Account Administrator
- [ ] Cloud admin designated
- [ ] Team members invited

**After Medium Priority Tasks:**
- [ ] APN membership active (paid)
- [ ] First solution submitted
- [ ] Migration scheduled (if applicable)

**After All Tasks:**
- [ ] 100% task completion
- [ ] Partner Central fully operational
- [ ] Team has access
- [ ] Solutions showcased
- [ ] Ready for AWS co-selling

---

**Generated**: 2026-01-12
**Quick Reference Version**: 1.0
