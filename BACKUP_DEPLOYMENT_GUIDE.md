# Backup Deployment Guide - Free Hosting

This guide will help you deploy a complete backup instance of Marathon 2026 on free hosting platforms.

## 🎯 Recommended Free Hosting Stack

### Option 1: Render.com (Recommended - Easiest)
- **Backend**: Render Web Service (Free tier)
- **Database**: Render PostgreSQL (Free tier - 90 days, then paid)
- **Frontend**: Render Static Site (Free tier)
- **Total Cost**: FREE for 90 days, then ~$7/month for DB

### Option 2: Railway.app
- **Backend**: Railway (Free $5 credit/month)
- **Database**: Railway PostgreSQL (Free tier)
- **Frontend**: Railway Static (Free tier)
- **Total Cost**: FREE (with usage limits)

### Option 3: Vercel + PlanetScale
- **Backend**: Vercel Serverless Functions (Free tier)
- **Database**: PlanetScale MySQL (Free tier - 5GB)
- **Frontend**: Vercel (Free tier)
- **Total Cost**: 100% FREE

## 📋 We'll Use: Render.com (Best for Full-Stack Apps)

---

## Step 1: Prepare the Application

### 1.1 Create Required Configuration Files

We need to create several files for Render deployment.

### 1.2 Update Database Connection

The app needs to support both MySQL (current) and PostgreSQL (Render).

---

## Step 2: Database Setup on Render

### 2.1 Create PostgreSQL Database

1. Go to https://render.com and sign up
2. Click "New +" → "PostgreSQL"
3. Configure:
   - **Name**: `marathon-2026-db`
   - **Database**: `marathon2026`
   - **User**: (auto-generated)
   - **Region**: Singapore (closest to India)
   - **Plan**: Free
4. Click "Create Database"
5. **Save the connection details** (Internal Database URL)

### 2.2 Initialize Database Schema

You'll need to run your SQL schema. Render provides a connection string like:
```
postgresql://user:password@host:port/database
```

---

## Step 3: Backend Deployment on Render

### 3.1 Create Web Service

1. Go to Render Dashboard
2. Click "New +" → "Web Service"
3. Connect your GitHub repository: `AkashDavidKumar/Marathon-2026`
4. Configure:
   - **Name**: `marathon-2026-backend`
   - **Region**: Singapore
   - **Branch**: `main`
   - **Root Directory**: `backend`
   - **Runtime**: Python 3
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app`
   - **Plan**: Free

### 3.2 Environment Variables

Add these in Render dashboard:
```
DATABASE_URL=<from Step 2.1>
FLASK_ENV=production
SECRET_KEY=<generate-random-string>
ALLOWED_ORIGINS=https://marathon-2026-frontend.onrender.com
```

---

## Step 4: Frontend Deployment on Render

### 4.1 Create Static Site

1. Click "New +" → "Static Site"
2. Connect same GitHub repo
3. Configure:
   - **Name**: `marathon-2026-frontend`
   - **Branch**: `main`
   - **Root Directory**: `frontend`
   - **Build Command**: (leave empty for static HTML)
   - **Publish Directory**: `.`

### 4.2 Update API Endpoint

The frontend needs to point to the backend URL.

---

## Step 5: Database Migration

### 5.1 Export Current MySQL Data

```bash
# On your current server
mysqldump -u root -p marathon2026 > marathon_backup.sql
```

### 5.2 Convert MySQL to PostgreSQL

We'll need to adjust the SQL syntax for PostgreSQL compatibility.

### 5.3 Import to Render PostgreSQL

```bash
# Using psql
psql <DATABASE_URL_from_render> < marathon_backup_postgres.sql
```

---

## Alternative: Quick Deploy with Railway.app

Railway is even simpler - it auto-detects everything!

### Railway Deployment Steps

1. Go to https://railway.app
2. Sign up with GitHub
3. Click "New Project" → "Deploy from GitHub repo"
4. Select `AkashDavidKumar/Marathon-2026`
5. Railway will auto-detect Python and deploy!
6. Add PostgreSQL: Click "+ New" → "Database" → "PostgreSQL"
7. Environment variables are auto-configured!

---

## 🚀 Automated Deployment Script

I'll create scripts to automate this process.

---

## Testing the Backup Deployment

After deployment, test:

1. **Backend Health Check**:
   ```
   https://marathon-2026-backend.onrender.com/health
   ```

2. **Frontend Access**:
   ```
   https://marathon-2026-frontend.onrender.com
   ```

3. **Database Connection**:
   - Login to admin panel
   - Check if data loads
   - Try creating a participant

---

## Monitoring & Maintenance

### Free Tier Limitations

**Render Free Tier**:
- ✅ Unlimited bandwidth
- ✅ Auto-deploy from GitHub
- ✅ Free SSL
- ⚠️ Spins down after 15 min inactivity (cold start ~30s)
- ⚠️ PostgreSQL free for 90 days only

**Railway Free Tier**:
- ✅ $5 credit/month
- ✅ Always on (no cold starts)
- ✅ PostgreSQL included
- ⚠️ Limited to $5/month usage

### Keep-Alive Strategy

For Render (to avoid cold starts):
```bash
# Use a cron job to ping every 10 minutes
*/10 * * * * curl https://marathon-2026-backend.onrender.com/health
```

Or use a free service like:
- UptimeRobot (https://uptimerobot.com)
- Cron-job.org (https://cron-job.org)

---

## Rollback Plan

If the backup deployment has issues:

1. **Check Logs**: Render Dashboard → Service → Logs
2. **Verify Environment Variables**: Settings → Environment
3. **Database Connection**: Test with psql
4. **Redeploy**: Manual Deploy → Clear build cache → Deploy

---

## Cost Breakdown

### Render (Recommended)
- **Months 1-3**: 100% FREE
- **Month 4+**: $7/month (PostgreSQL only)
- **Total Year 1**: ~$63

### Railway
- **Always**: FREE (if under $5/month)
- **Typical usage**: $2-3/month
- **Total Year 1**: ~$24-36

### Vercel + PlanetScale
- **Always**: 100% FREE
- **Limits**: 100GB bandwidth, 5GB DB
- **Total Year 1**: $0

---

## Next Steps

I'll now create:
1. ✅ Render deployment configuration files
2. ✅ Database migration scripts
3. ✅ Frontend API configuration
4. ✅ Automated deployment script
5. ✅ Health check monitoring setup

Would you like me to proceed with Render.com or would you prefer Railway.app?
