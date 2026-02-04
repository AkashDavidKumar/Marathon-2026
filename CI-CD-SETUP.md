# 🚀 Automated CI/CD Deployment Setup

## Overview
This setup enables automatic deployment from GitHub to all 4 AWS EC2 servers (1 Master + 3 Workers) whenever you push code changes.

## 🎯 What You Get
- ✅ Push code to GitHub → Automatic deployment to all 4 servers
- ✅ No manual SSH to each server
- ✅ Automatic service restart on all servers
- ✅ Deployment verification
- ✅ Rollback capability

---

## 📋 Prerequisites

1. **GitHub Repository** - Your code must be in a GitHub repository
2. **SSH Access** - You should be able to SSH into all 4 servers
3. **Systemd Service** - Application running as a systemd service on each server

---

## 🔧 Setup Instructions

### Step 1: Initial Server Setup (One-time on Each Server)

Run these commands on **each of your 4 servers** (Master + 3 Workers):

```bash
# SSH into each server
ssh ubuntu@your-server-ip

# Install required packages
sudo apt update
sudo apt install -y python3-pip gunicorn nginx

# Create application directory
sudo mkdir -p /var/www/debug-marathon
sudo chown ubuntu:ubuntu /var/www/debug-marathon

# Install pip packages globally
sudo pip3 install flask flask-cors pymysql gunicorn

# Copy systemd service file (from your repo)
sudo cp /path/to/debug-marathon.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable debug-marathon
sudo systemctl start debug-marathon
```

### Step 2: Configure GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add the following:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `EC2_SSH_KEY` | Contents of your .pem file | Your EC2 private key |
| `MASTER_IP` | e.g., `54.123.45.67` | Master server public IP |
| `WORKER1_IP` | e.g., `54.123.45.68` | Worker 1 public IP |
| `WORKER2_IP` | e.g., `54.123.45.69` | Worker 2 public IP |
| `WORKER3_IP` | e.g., `54.123.45.70` | Worker 3 public IP |

**To get your SSH key contents:**
```powershell
# On Windows
Get-Content debug-marathon-key.pem | clip
```

Then paste into GitHub Secrets.

### Step 3: Push Workflow to GitHub

```bash
# Navigate to your project directory
cd c:\Users\AD41934\Downloads\GlitchFix_Final-main\GlitchFix_Final-main

# Add all files including the new workflow
git add .
git commit -m "Add automated CI/CD deployment"
git push origin main
```

---

## 🎮 How to Use

### Automatic Deployment
Simply push code to GitHub:
```bash
git add .
git commit -m "Fixed login bug"
git push origin main
```

The GitHub Action will automatically:
1. ✅ Package your application
2. ✅ Deploy to Master server
3. ✅ Deploy to Worker 1, 2, 3
4. ✅ Restart services on all servers
5. ✅ Verify deployments

### Manual Deployment (Alternative)
If you prefer manual deployment:

```bash
# Edit server IPs in server-inventory.env first
export MASTER_IP=your-master-ip
export WORKER1_IP=your-worker1-ip
export WORKER2_IP=your-worker2-ip
export WORKER3_IP=your-worker3-ip

# Run deployment script
bash deploy-multi-server.sh
```

---

## 📊 Monitoring Deployments

### View GitHub Actions
1. Go to your GitHub repository
2. Click **Actions** tab
3. See deployment status in real-time

### Check Deployment Logs
```bash
# SSH into any server
ssh ubuntu@your-server-ip

# View application logs
sudo journalctl -u debug-marathon -f

# Check service status
sudo systemctl status debug-marathon
```

---

## 🔍 Troubleshooting

### Deployment Fails with "Permission denied"
**Solution:** Check GitHub Secrets has correct SSH key with proper formatting

### Service doesn't restart
**Solution:** Verify systemd service is installed:
```bash
sudo systemctl status debug-marathon
```

### Changes not reflecting
**Solution:** Clear cache or check if correct branch is deployed:
```bash
cd /var/www/debug-marathon
git log -1  # See last deployed commit
```

---

## 🎛️ Configuration Files

| File | Purpose |
|------|---------|
| `.github/workflows/deploy.yml` | GitHub Actions workflow |
| `deploy-multi-server.sh` | Manual deployment script |
| `server-inventory.env` | Server IP configuration |
| `debug-marathon.service` | Systemd service definition |

---

## 🔐 Security Best Practices

1. **Never commit** `.pem` files or `server-inventory.env` with real IPs to Git
2. Use GitHub Secrets for sensitive data
3. Restrict SSH key permissions: `chmod 600 debug-marathon-key.pem`
4. Use IAM roles instead of SSH keys when possible
5. Enable GitHub branch protection for main branch

---

## 🚀 Advanced Features

### Deploy to Specific Servers Only
Edit `.github/workflows/deploy.yml` and comment out unwanted server steps.

### Blue-Green Deployment
Modify workflow to:
1. Deploy to Worker servers first
2. Test endpoints
3. Deploy to Master last

### Rollback to Previous Version
```bash
# On each server
cd /var/www/debug-marathon
git log  # Find previous commit hash
git checkout <commit-hash>
sudo systemctl restart debug-marathon
```

### Add Slack Notifications
Add to workflow:
```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 📈 Next Steps

1. ✅ Set up GitHub Secrets (most important!)
2. ✅ Test with a small change (e.g., add a comment)
3. ✅ Monitor deployment in GitHub Actions
4. ✅ Verify on all 4 servers
5. ✅ Set up automated backups
6. ✅ Configure health checks in Load Balancer

---

## 💡 Benefits

**Before (Manual):**
- 🔴 Make change → SSH to 4 servers → Upload → Restart → 30+ minutes

**After (Automated):**
- 🟢 Make change → Push to GitHub → Done → 5 minutes

---

## 📞 Quick Reference

```bash
# Test SSH connection
ssh -i debug-marathon-key.pem ubuntu@your-server-ip

# Check all servers status
for ip in MASTER WORKER1 WORKER2 WORKER3; do
  ssh ubuntu@$ip "hostname && sudo systemctl status debug-marathon"
done

# Emergency rollback
git revert HEAD
git push origin main  # Auto-deploys previous version

# View real-time logs
ssh ubuntu@your-master-ip "sudo journalctl -u debug-marathon -f"
```

---

## ✅ Verification Checklist

After setup, verify:

- [ ] GitHub Secrets configured with all 5 values
- [ ] Can SSH to all 4 servers
- [ ] Systemd service running on all servers
- [ ] GitHub Actions workflow file pushed to repo
- [ ] Test deployment completes successfully
- [ ] Application accessible via Load Balancer
- [ ] All 4 servers showing same version

---

## 🆘 Support

If deployment fails:
1. Check GitHub Actions logs for error messages
2. SSH to failed server and check `sudo journalctl -u debug-marathon`
3. Verify all GitHub Secrets are correctly set
4. Ensure SSH key has no password protection
5. Check security groups allow SSH (port 22) from GitHub's IP ranges

---

**Need Help?** Check the GitHub Actions tab for detailed error logs!
