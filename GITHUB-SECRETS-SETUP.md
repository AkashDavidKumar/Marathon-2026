# 🔐 GitHub Secrets Setup Guide

## Required Secrets for CI/CD

Configure these secrets in your GitHub repository: **AkashDavidKumar/Marathon-2026**

### How to Add Secrets

1. Go to: https://github.com/AkashDavidKumar/Marathon-2026/settings/secrets/actions
2. Click **"New repository secret"**
3. Add each secret below

---

## 📋 Secrets to Configure

### 1. EC2 SSH Key
**Secret Name:** `EC2_SSH_KEY`

**Value:** Contents of your `debug-marathon-key-v2.pem` file

```powershell
# On Windows PowerShell, run this to copy to clipboard:
Get-Content "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem" | Set-Clipboard
```

Then paste into GitHub Secret value field.

**⚠️ Important:** 
- Include the entire file including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`
- Preserve all line breaks
- No extra spaces or characters

---

### 2. Server IP Addresses

| Secret Name | Value |
|-------------|-------|
| `MASTER_IP` | `47.130.2.117` |
| `WORKER1_IP` | `13.229.109.204` |
| `WORKER2_IP` | `13.212.253.90` |
| `WORKER3_IP` | `54.169.5.230` |

---

### 3. AWS Credentials (for S3 Deployment)

**Secret Name:** `AWS_ACCESS_KEY_ID`
**Value:** Your AWS Access Key ID

**Secret Name:** `AWS_SECRET_ACCESS_KEY`
**Value:** Your AWS Secret Access Key

> **How to get AWS credentials:**
> 1. Go to AWS IAM Console
> 2. Create a new user with programmatic access
> 3. Attach policy: `AmazonS3FullAccess` (or custom policy with S3 write permissions)
> 4. Save the Access Key ID and Secret Access Key

---

### 4. Database Password (Optional but Recommended)

**Secret Name:** `DB_PASSWORD`
**Value:** `wCZ52GAXKjZOA55q`

> This can be used in deployment scripts if you need to run database migrations automatically.

---

## ✅ Verification Checklist

After adding all secrets, verify:

- [ ] `EC2_SSH_KEY` - Complete .pem file contents
- [ ] `MASTER_IP` - 47.130.2.117
- [ ] `WORKER1_IP` - 13.229.109.204
- [ ] `WORKER2_IP` - 13.212.253.90
- [ ] `WORKER3_IP` - 54.169.5.230
- [ ] `AWS_ACCESS_KEY_ID` - Your AWS access key
- [ ] `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
- [ ] `DB_PASSWORD` - (Optional) Your RDS password

**Total: 8 secrets (7 required + 1 optional)**

---

## 🧪 Test Your Setup

After configuring secrets:

1. Make a small change to your code (e.g., add a comment)
2. Commit and push to main branch:
   ```bash
   git add .
   git commit -m "Test: CI/CD deployment"
   git push origin main
   ```
3. Go to **Actions** tab in GitHub
4. Watch the deployment workflow run
5. Verify deployment on all 4 servers

---

## 🔒 Security Best Practices

1. **Never commit** real `.pem` files or `server-inventory.env` with real values
2. **Rotate credentials** periodically (every 90 days recommended)
3. **Use IAM roles** when possible instead of hardcoded credentials
4. **Limit permissions** - AWS user should only have S3 and EC2 describe permissions
5. **Enable branch protection** on main branch to prevent accidental pushes
6. **Review GitHub Actions logs** - secrets are masked automatically

---

## 📞 Quick Command Reference

```powershell
# Copy SSH key to clipboard (Windows)
Get-Content "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem" | Set-Clipboard

# Verify SSH key format
Get-Content "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem" | Select-Object -First 1
# Should show: -----BEGIN RSA PRIVATE KEY-----

# Test SSH connection to servers
ssh -i "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem" ubuntu@47.130.2.117 "hostname"
ssh -i "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem" ubuntu@13.229.109.204 "hostname"
ssh -i "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem" ubuntu@13.212.253.90 "hostname"
ssh -i "d:\Marathon\Final\aws-migration\debug-marathon-key-v2.pem" ubuntu@54.169.5.230 "hostname"
```

---

## 🆘 Troubleshooting

### "Permission denied (publickey)" error
- ✅ Check that `EC2_SSH_KEY` secret contains the complete .pem file
- ✅ Verify SSH key has no password protection
- ✅ Confirm IP addresses are correct

### "AWS credentials not found" error
- ✅ Check `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set
- ✅ Verify IAM user has S3 permissions

### Deployment succeeds but changes not visible
- ✅ Clear browser cache
- ✅ Check S3 bucket: https://s3.console.aws.amazon.com/s3/buckets/debug-marathon-assets-052150906633
- ✅ Verify ALB is routing to updated backend servers

---

**Once all secrets are configured, you're ready to deploy!** 🚀
