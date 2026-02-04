# 🔐 GitHub Secrets & Environment Management

## Repository: AkashDavidKumar/Marathon-2026

---

## 📦 Option 1: Repository Secrets (Simple - Recommended for Start)

**Best for:** Single production environment

### How to Add Repository Secrets

1. **Navigate to your repository:**
   ```
   https://github.com/AkashDavidKumar/Marathon-2026/settings/secrets/actions
   ```

2. **Click:** "New repository secret"

3. **Add each secret:**

### Required Secrets List

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `EC2_SSH_KEY` | Contents of `debug-marathon-key-v2.pem` | SSH private key for EC2 access |
| `MASTER_IP` | `47.130.2.117` | Master server public IP |
| `WORKER1_IP` | `13.229.109.204` | Worker 1 public IP |
| `WORKER2_IP` | `13.212.253.90` | Worker 2 public IP |
| `WORKER3_IP` | `54.169.5.230` | Worker 3 public IP |
| `AWS_ACCESS_KEY_ID` | Your AWS access key | For S3 deployment |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | For S3 deployment |
| `DB_PASSWORD` | `wCZ52GAXKjZOA55q` | (Optional) RDS password |

### Copy SSH Key to Clipboard

```powershell
# Windows PowerShell
Get-Content "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem" | Set-Clipboard
```

Then paste into GitHub Secret field.

---

## 🌍 Option 2: Environment Secrets (Advanced - Multiple Environments)

**Best for:** Separate staging and production environments

### Why Use Environments?

- ✅ Separate secrets for staging/production
- ✅ Require manual approval before production deployment
- ✅ Better security and control
- ✅ Environment-specific variables

### Step 1: Create Environments

1. Go to: `https://github.com/AkashDavidKumar/Marathon-2026/settings/environments`

2. Click **"New environment"**

3. Create two environments:
   - **staging**
   - **production**

### Step 2: Configure Production Environment (with approval)

1. Click on **"production"** environment
2. Check **"Required reviewers"**
3. Add yourself as reviewer
4. Set deployment branches: **Only main branch**

### Step 3: Add Environment-Specific Secrets

#### For **Production** Environment:

Go to: Production environment settings → Add Secret

| Secret Name | Value |
|-------------|-------|
| `EC2_SSH_KEY` | Production .pem key |
| `MASTER_IP` | `47.130.2.117` |
| `WORKER1_IP` | `13.229.109.204` |
| `WORKER2_IP` | `13.212.253.90` |
| `WORKER3_IP` | `54.169.5.230` |
| `AWS_ACCESS_KEY_ID` | Production AWS key |
| `AWS_SECRET_ACCESS_KEY` | Production AWS secret |
| `DB_PASSWORD` | `wCZ52GAXKjZOA55q` |
| `S3_BUCKET` | `debug-marathon-assets-052150906633` |
| `ALB_DNS` | `debug-marathon-alb-1798040122.ap-southeast-1.elb.amazonaws.com` |

#### For **Staging** Environment (if you have staging servers):

| Secret Name | Value |
|-------------|-------|
| `EC2_SSH_KEY` | Staging .pem key |
| `MASTER_IP` | Staging master IP |
| `WORKER1_IP` | Staging worker 1 IP |
| ... | ... |

### Step 4: Update Workflow to Use Environments

Modify `.github/workflows/deploy.yml`:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Add this line
    
    steps:
      # ... rest of the workflow
```

Or for multi-environment setup:

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    if: github.ref == 'refs/heads/develop'
    # ... deployment steps

  deploy-production:
    runs-on: ubuntu-latest
    environment: production
    if: github.ref == 'refs/heads/main'
    needs: deploy-staging  # Deploy staging first
    # ... deployment steps
```

---

## 🔧 Managing Secrets via GitHub CLI

### Install GitHub CLI

```powershell
# Windows (using winget)
winget install GitHub.cli

# Or using Chocolatey
choco install gh
```

### Login

```bash
gh auth login
```

### Add Secrets via CLI

```bash
# Add repository secret
gh secret set EC2_SSH_KEY < "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem"
gh secret set MASTER_IP -b "47.130.2.117"
gh secret set WORKER1_IP -b "13.229.109.204"
gh secret set WORKER2_IP -b "13.212.253.90"
gh secret set WORKER3_IP -b "54.169.5.230"

# Add environment secret
gh secret set AWS_ACCESS_KEY_ID --env production -b "YOUR_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --env production -b "YOUR_SECRET"
```

### List Secrets

```bash
# List repository secrets
gh secret list

# List environment secrets
gh secret list --env production
```

### Delete Secret

```bash
gh secret delete SECRET_NAME
gh secret delete SECRET_NAME --env production
```

---

## 🎯 Quick Setup Script (PowerShell)

Save this as `setup-github-secrets.ps1`:

```powershell
# Setup GitHub Secrets for Marathon-2026
# Requires: GitHub CLI (gh) installed and authenticated

$repo = "AkashDavidKumar/Marathon-2026"
$keyPath = "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem"

Write-Host "🔐 Setting up GitHub Secrets for $repo" -ForegroundColor Green

# Add SSH Key
Write-Host "Adding EC2_SSH_KEY..." -ForegroundColor Yellow
gh secret set EC2_SSH_KEY --repo $repo < $keyPath

# Add Server IPs
Write-Host "Adding Server IPs..." -ForegroundColor Yellow
gh secret set MASTER_IP --repo $repo -b "47.130.2.117"
gh secret set WORKER1_IP --repo $repo -b "13.229.109.204"
gh secret set WORKER2_IP --repo $repo -b "13.212.253.90"
gh secret set WORKER3_IP --repo $repo -b "54.169.5.230"

# Prompt for AWS credentials
Write-Host "`nPlease enter AWS credentials:" -ForegroundColor Cyan
$awsKeyId = Read-Host "AWS Access Key ID"
$awsSecret = Read-Host "AWS Secret Access Key" -AsSecureString
$awsSecretPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($awsSecret))

gh secret set AWS_ACCESS_KEY_ID --repo $repo -b $awsKeyId
gh secret set AWS_SECRET_ACCESS_KEY --repo $repo -b $awsSecretPlain

# Add DB password
gh secret set DB_PASSWORD --repo $repo -b "wCZ52GAXKjZOA55q"

Write-Host "`n✅ All secrets configured successfully!" -ForegroundColor Green
Write-Host "View secrets at: https://github.com/$repo/settings/secrets/actions" -ForegroundColor Cyan
```

Run it:

```powershell
.\setup-github-secrets.ps1
```

---

## 📋 Verification Checklist

After adding secrets, verify:

```bash
# List all secrets
gh secret list --repo AkashDavidKumar/Marathon-2026

# Test deployment
git add .
git commit -m "Test: Verify secrets configuration"
git push origin main
```

Then check: https://github.com/AkashDavidKumar/Marathon-2026/actions

---

## 🔒 Security Best Practices

### DO:
- ✅ Use environment secrets for production
- ✅ Enable required reviewers for production
- ✅ Rotate credentials every 90 days
- ✅ Use least-privilege AWS IAM policies
- ✅ Enable branch protection on main
- ✅ Review audit logs regularly

### DON'T:
- ❌ Commit secrets to repository
- ❌ Share secrets in chat/email
- ❌ Use same secrets for staging/production
- ❌ Grant unnecessary permissions
- ❌ Hardcode IPs or passwords in code

---

## 🆘 Troubleshooting

### Can't Access Secrets Settings

**Problem:** Don't see Settings tab

**Solution:** You need **Admin** or **Write** access to the repository

### Secret Not Working in Workflow

**Problem:** Workflow can't access secret

**Solutions:**
1. Verify secret name matches exactly (case-sensitive)
2. Check if using environment - ensure environment name matches
3. Re-create the secret (sometimes helps)
4. Check workflow syntax: `${{ secrets.SECRET_NAME }}`

### AWS Credentials Invalid

**Problem:** S3 deployment fails with credentials error

**Solution:**
```bash
# Test AWS credentials locally first
aws configure
aws s3 ls s3://debug-marathon-assets-052150906633/

# Then add to GitHub with same credentials
gh secret set AWS_ACCESS_KEY_ID -b "YOUR_KEY"
gh secret set AWS_SECRET_ACCESS_KEY -b "YOUR_SECRET"
```

---

## 📚 Additional Resources

- **GitHub Secrets Documentation:** https://docs.github.com/en/actions/security-guides/encrypted-secrets
- **GitHub Environments:** https://docs.github.com/en/actions/deployment/targeting-different-environments
- **GitHub CLI:** https://cli.github.com/manual/gh_secret

---

## 🚀 Next Steps

1. ✅ Choose: Repository Secrets (simple) or Environment Secrets (advanced)
2. ✅ Add all required secrets using web UI or CLI
3. ✅ Test deployment with a small change
4. ✅ Verify deployment in GitHub Actions tab
5. ✅ Check all 4 servers and S3 bucket

**Ready to deploy!** 🎉
