# 🚀 Quick Deploy to Railway.app - Complete Guide

## Why Railway.app?

✅ **100% Free** - $5 credit/month (enough for this app)  
✅ **Auto-Deploy** - Connects to GitHub, deploys on push  
✅ **PostgreSQL Included** - Free database included  
✅ **No Cold Starts** - Always on, no spin-down  
✅ **Simple Setup** - 5 minutes to deploy  

---

## 📋 Prerequisites

- GitHub account with Marathon-2026 repository
- Railway.app account (sign up with GitHub)

---

## 🎯 Step-by-Step Deployment

### Step 1: Sign Up for Railway

1. Go to https://railway.app
2. Click "Login" → "Login with GitHub"
3. Authorize Railway to access your repositories

### Step 2: Create New Project

1. Click "New Project"
2. Select "Deploy from GitHub repo"
3. Choose `AkashDavidKumar/Marathon-2026`
4. Railway will detect it's a Python app and start deploying!

### Step 3: Add PostgreSQL Database

1. In your project, click "+ New"
2. Select "Database" → "Add PostgreSQL"
3. Railway automatically creates the database
4. **Important**: Railway auto-connects the DATABASE_URL!

### Step 4: Configure Environment Variables

1. Click on your backend service
2. Go to "Variables" tab
3. Add these variables:

```
FLASK_ENV=production
SECRET_KEY=your-super-secret-key-change-this-12345
ALLOWED_ORIGINS=*
PORT=5000
```

Railway automatically provides:
- `DATABASE_URL` (PostgreSQL connection string)
- `PORT` (assigned port)

### Step 5: Initialize Database Schema

1. Click on PostgreSQL service
2. Click "Data" tab
3. Click "Query" button
4. Copy-paste the contents of `backend/database_setup.sql`
5. **Modify for PostgreSQL** (see conversion guide below)
6. Click "Run"

### Step 6: Deploy Frontend

Railway can also host static sites!

1. In the same project, click "+ New"
2. Select "Empty Service"
3. Name it "frontend"
4. Go to Settings → Source
5. Connect to same GitHub repo
6. Set Root Directory: `frontend`
7. Add build command: (leave empty for static)
8. Deploy!

### Step 7: Update Frontend API URL

1. Get your backend URL from Railway (e.g., `marathon-backend.up.railway.app`)
2. Update `frontend/js/api.js`:

```javascript
const API_BASE_URL = 'https://marathon-backend.up.railway.app';
```

3. Commit and push - Railway auto-deploys!

---

## 🔄 MySQL to PostgreSQL Conversion

### Key Differences to Fix

1. **AUTO_INCREMENT → SERIAL**
```sql
-- MySQL
user_id INT AUTO_INCREMENT PRIMARY KEY

-- PostgreSQL
user_id SERIAL PRIMARY KEY
```

2. **DATETIME → TIMESTAMP**
```sql
-- MySQL
created_at DATETIME DEFAULT CURRENT_TIMESTAMP

-- PostgreSQL
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
```

3. **TEXT Types**
```sql
-- MySQL
description TEXT

-- PostgreSQL  
description TEXT  -- Same!
```

4. **JSON Type**
```sql
-- MySQL
metadata JSON

-- PostgreSQL
metadata JSONB  -- Better performance
```

5. **ON DUPLICATE KEY UPDATE → ON CONFLICT**
```sql
-- MySQL
INSERT INTO table (id, value) VALUES (1, 'x')
ON DUPLICATE KEY UPDATE value='x'

-- PostgreSQL
INSERT INTO table (id, value) VALUES (1, 'x')
ON CONFLICT (id) DO UPDATE SET value='x'
```

### Automated Conversion Script

I'll create a script to convert your schema automatically!

---

## 🔧 Database Connection Update

Your `db_connection.py` needs to support both MySQL and PostgreSQL.

### Check if DATABASE_URL exists (PostgreSQL on Railway)
```python
import os

DATABASE_URL = os.getenv('DATABASE_URL')

if DATABASE_URL:
    # Use PostgreSQL (Railway/Render)
    import psycopg2
    from psycopg2.extras import RealDictCursor
    
    conn = psycopg2.connect(DATABASE_URL)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
else:
    # Use MySQL (local/AWS)
    import mysql.connector
    # ... existing MySQL code
```

---

## 📊 Monitoring Your Deployment

### Railway Dashboard

1. **Metrics**: View CPU, Memory, Network usage
2. **Logs**: Real-time application logs
3. **Deployments**: History of all deployments
4. **Usage**: Track your $5 monthly credit

### Health Check

Once deployed, test:
```
https://your-backend.up.railway.app/health
```

Should return:
```json
{
  "status": "healthy",
  "database": "connected"
}
```

---

## 💰 Cost Estimate

### Railway Free Tier

- **Monthly Credit**: $5
- **Typical Usage**:
  - Backend: ~$2-3/month
  - Database: ~$1-2/month
  - Frontend: ~$0.50/month
- **Total**: ~$3.50-5.50/month

### If you exceed $5/month:
- Add a credit card (charges only for overage)
- Or optimize (reduce resources)
- Or use Render.com (free for 90 days)

---

## 🚨 Troubleshooting

### Build Fails

**Error**: `Could not find requirements.txt`
- **Fix**: Ensure Root Directory is set to `backend`

**Error**: `Module not found`
- **Fix**: Check `requirements.txt` has all dependencies

### Database Connection Fails

**Error**: `Connection refused`
- **Fix**: Ensure DATABASE_URL is set in environment variables
- **Fix**: Check PostgreSQL service is running

### Frontend Can't Connect to Backend

**Error**: `CORS error`
- **Fix**: Add frontend URL to ALLOWED_ORIGINS
- **Fix**: Update API_BASE_URL in frontend

### App Crashes

1. Check Railway logs: Service → Deployments → View Logs
2. Look for Python errors
3. Verify environment variables
4. Test database connection

---

## 🎉 Success Checklist

After deployment, verify:

- [ ] Backend is accessible: `https://your-backend.up.railway.app/health`
- [ ] Database is connected (health check shows "connected")
- [ ] Frontend loads: `https://your-frontend.up.railway.app`
- [ ] Can login to admin panel
- [ ] Can create participants
- [ ] Can view questions
- [ ] Socket.IO works (real-time updates)

---

## 🔄 Continuous Deployment

Railway automatically deploys when you push to GitHub!

```bash
git add .
git commit -m "Update feature"
git push origin main
```

Railway detects the push and redeploys automatically! 🚀

---

## 📝 Alternative: Manual Deployment Steps

If you prefer manual control:

1. Fork the repository
2. Make changes locally
3. Push to your fork
4. Railway deploys from your fork
5. You control when to deploy

---

## 🆘 Need Help?

- Railway Docs: https://docs.railway.app
- Railway Discord: https://discord.gg/railway
- GitHub Issues: Create an issue in your repo

---

## Next Steps

I'll now create:
1. ✅ PostgreSQL schema conversion script
2. ✅ Updated db_connection.py for dual database support
3. ✅ Frontend API configuration helper
4. ✅ Health check endpoint improvements

Ready to deploy? Let's do it! 🚀
