# 🚀 GitHub Actions Workflow Setup Guide

This guide explains how to configure and use the GitHub Actions workflows for automated Terraform infrastructure deployment.

## 📋 Prerequisites

### 1. AWS Credentials Setup
You need to configure AWS credentials as GitHub secrets:

1. Go to your repository **Settings** → **Secrets and variables** → **Actions**
2. Add the following **Repository secrets**:

```bash
# Required AWS credentials
AWS_ACCESS_KEY_ID=your-aws-access-key-id
AWS_SECRET_ACCESS_KEY=your-aws-secret-access-key

# Optional but recommended for cost estimation
INFRACOST_API_KEY=your-infracost-api-key  # Get from https://infracost.io
```

### 2. GitHub Environments Setup
Configure deployment environments for approval workflows:

1. Go to **Settings** → **Environments**
2. Create environments: `dev`, `staging`, `prod`
3. For `staging` and `prod`, add **Required reviewers**
4. Optional: Add environment secrets if different AWS accounts per environment

### 3. Repository Settings
Configure branch protection rules:

1. Go to **Settings** → **Branches**
2. Add rule for `main` branch:
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
   - ✅ Select: `Validate Terraform`, `Plan (dev)`
   - ✅ Restrict pushes that create files

## 🔄 Workflow Overview

### Terraform Deployment (`terraform-deploy.yml`)
**Triggers:**
- ✅ **Push to main**: Automatic deployment after PR merge
- ✅ **Manual dispatch**: Deploy any environment on-demand
- ✅ **Pull Request**: Plan validation and preview

**Features:**
- 🔍 **Intelligent change detection**: Only runs when Terraform files change
- 📋 **Multi-environment support**: Dev, staging, production
- 🔐 **Environment protection**: Approval required for staging/prod
- 🎯 **Plan validation**: Shows exact changes before deployment
- 📊 **Deployment verification**: Validates AWS resources after deployment
- 📢 **Status notifications**: Comments on PRs, Slack integration
- 📁 **Artifact management**: Stores plans and outputs securely

### Terraform Validation (`terraform-validate.yml`)
**Triggers:**
- ✅ **Pull Requests** to main/develop
- ✅ **Push** to feature/fix branches

**Features:**
- ✨ **Format checking**: Ensures consistent code style
- ✅ **Syntax validation**: Catches configuration errors early
- 🛡️ **Security scanning**: Identifies security issues (tfsec)
- 💰 **Cost estimation**: Shows infrastructure costs (Infracost)
- 📚 **Documentation checks**: Ensures README files exist
- 💬 **PR comments**: Detailed validation results on pull requests

## 🎯 Usage Examples

### 1. Regular Development Flow
```bash
# Create feature branch
git checkout -b fix/s3-lifecycle-transitions

# Make your changes
# ... edit Terraform files ...

# Commit and push
git add .
git commit -m "Fix S3 lifecycle configuration issues"
git push origin fix/s3-lifecycle-transitions

# Create Pull Request
# ✅ Validation workflow runs automatically
# ✅ Plan preview appears in PR comments
# ✅ Reviewers can see exact changes

# Merge PR
# ✅ Deployment workflow triggers automatically
# ✅ Infrastructure deployed to dev environment
```

### 2. Manual Deployment
Use for deploying to specific environments or emergency fixes:

1. Go to **Actions** → **🚀 Terraform Infrastructure Deployment**
2. Click **Run workflow**
3. Select:
   - **Environment**: `dev`, `staging`, or `prod`
   - **Action**: `plan` (preview) or `apply` (deploy)
4. Click **Run workflow**

### 3. Production Deployment
```bash
# After dev testing is successful, deploy to staging
# Via manual dispatch: environment=staging, action=apply

# After staging validation, deploy to production
# Via manual dispatch: environment=prod, action=apply
# ⚠️ Requires approval from designated reviewers
```

## 📊 Workflow Status and Monitoring

### PR Comments
The workflows automatically comment on pull requests with:
- ✅ **Validation results**: Format, syntax, security checks
- 📋 **Plan preview**: Exact resources to be created/modified
- 💰 **Cost estimation**: Expected monthly costs
- 🚀 **Deployment status**: Success/failure with details

### GitHub Environment Pages
Each environment shows:
- 📅 **Deployment history**: Timeline of all deployments
- 🔗 **Application URLs**: Direct links to deployed infrastructure
- 📊 **Resource information**: VPC IDs, cluster names, etc.
- ⏱️ **Deployment duration**: Time taken for each deployment

### Artifacts and Logs
Workflows store:
- 📁 **Terraform plans**: Encrypted plan files for exact deployment
- 📋 **Deployment outputs**: JSON files with resource information
- 🛡️ **Security scan results**: tfsec findings and recommendations
- 📊 **Validation reports**: Detailed check results

## 🔧 Troubleshooting

### Common Issues

#### 1. AWS Credentials Error
```
Error: could not retrieve caller identity
```
**Solution**: Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in repository secrets.

#### 2. Terraform Backend Error
```
Error: Failed to get existing workspaces
```
**Solution**: Ensure your AWS credentials have S3 and DynamoDB permissions for the Terraform backend.

#### 3. Environment Not Found
```
Error: environment "staging" not found
```
**Solution**: Create the environment in repository Settings → Environments.

#### 4. Plan File Not Found
```
Error: tfplan-dev-abc123.tfplan not found
```
**Solution**: The plan job failed. Check the plan step logs for Terraform errors.

### Debugging Steps

1. **Check workflow logs**:
   - Go to **Actions** tab
   - Click on the failed workflow
   - Expand failed job steps

2. **Verify secrets**:
   - Settings → Secrets and variables → Actions
   - Ensure all required secrets are set

3. **Test AWS access manually**:
   ```bash
   aws sts get-caller-identity
   aws s3 ls  # Should list buckets
   ```

4. **Validate Terraform locally**:
   ```bash
   cd infrastructure/terraform/core
   terraform init
   terraform validate
   terraform plan -var-file="terraform.dev.tfvars"
   ```

## 📞 Advanced Configuration

### Custom Notifications
To enable Slack notifications:

1. Create a Slack webhook URL
2. Add to repository variables: `SLACK_WEBHOOK_URL`
3. Workflow will automatically send deployment status

### Multi-Account Setup
For separate AWS accounts per environment:

1. Create environment-specific secrets:
   - Environment `dev`: `AWS_ACCESS_KEY_ID_DEV`, `AWS_SECRET_ACCESS_KEY_DEV`
   - Environment `staging`: `AWS_ACCESS_KEY_ID_STAGING`, etc.
2. Update workflow to use environment-specific credentials

### Custom Terraform Versions
Update the `TF_VERSION` environment variable in both workflows:
```yaml
env:
  TF_VERSION: '1.6.0'  # Change to your desired version
```

### Additional Environments
To add a new environment (e.g., `test`):

1. Create `terraform.test.tfvars` file
2. Add `test` to the workflow environment choices
3. Create GitHub environment: Settings → Environments → New environment

## 🎉 What Happens When You Merge Your S3 Fix Branch?

When you merge your `fix/s3-lifecycle-transitions` branch to `main`:

1. **🔍 Change Detection**: Workflow detects Terraform changes
2. **📋 Plan Generation**: Creates plan with your S3 lifecycle fixes  
3. **🚀 Automatic Deployment**: Deploys to dev environment
4. **✅ Resource Verification**: Verifies S3 buckets and lifecycle rules
5. **📊 Status Update**: Comments on the merged PR with deployment status
6. **🎯 Ready Infrastructure**: Your fixed infrastructure is live at `https://dev.diatonic.ai`

The entire process is automated, secure, and provides full visibility into what's being deployed! 🚀
