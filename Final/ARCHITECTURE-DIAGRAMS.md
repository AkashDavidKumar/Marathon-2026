# 🎨 Marathon-2026 Architecture Diagrams

> Visual guide to understand how everything works together

---

## 🌐 High-Level Architecture

```
                          INTERNET
                             |
                             |
                    [Users Worldwide]
                             |
                             ↓
                   ┌─────────────────┐
                   │  ROUTE 53 (DNS) │ ← Your Domain (optional)
                   └─────────────────┘
                             |
                             ↓
        ┌────────────────────────────────────────┐
        │   APPLICATION LOAD BALANCER (ALB)      │
        │   - Health checks                      │
        │   - SSL/TLS termination                │
        │   - Traffic distribution                │
        └────────────────────────────────────────┘
                 |          |          |
        ┌────────┴────┬─────┴─────┬────┴────────┐
        |             |           |              |
        ↓             ↓           ↓              ↓
   [EC2 #1]      [EC2 #2]    [EC2 #3]  ...  [EC2 #6]
   ┌────────┐   ┌────────┐   ┌────────┐     ┌────────┐
   │ Nginx  │   │ Nginx  │   │ Nginx  │     │ Nginx  │
   │   +    │   │   +    │   │   +    │     │   +    │
   │Gunicorn│   │Gunicorn│   │Gunicorn│     │Gunicorn│
   │   +    │   │   +    │   │   +    │     │   +    │
   │ Flask  │   │ Flask  │   │ Flask  │     │ Flask  │
   └────────┘   └────────┘   └────────┘     └────────┘
        |             |           |              |
        └─────────────┴───────────┴──────────────┘
                         |
                         ↓
              ┌────────────────────┐
              │   RDS MySQL        │
              │   - Connection Pool │
              │   - Auto Backup    │
              │   - Multi-AZ       │
              └────────────────────┘
```

---

## 📊 Request Flow Diagram

```
1. User Types URL
   ↓
2. DNS Resolution (Route 53)
   ↓
3. Load Balancer Receives Request
   ↓
4. ALB Checks Health of Servers
   ↓
5. ALB Routes to Healthy Server
   ↓
6. Nginx Receives Request
   ├─ Static Files → Served Directly
   └─ API Request → Forwards to Gunicorn
       ↓
7. Gunicorn Passes to Flask App
   ↓
8. Flask Processes Request
   ├─ Read Data → Query MySQL
   ├─ Write Data → Insert to MySQL
   └─ Business Logic
       ↓
9. Flask Returns Response
   ↓
10. Gunicorn → Nginx → ALB → User
```

---

## 🔒 Security Architecture

```
                  ┌─────────────────────┐
                  │    PUBLIC SUBNET    │
                  │                     │
                  │  ┌──────────────┐   │
  INTERNET ─────►│  │ Load Balancer│   │
    (Port 80/443)│  └──────────────┘   │
                  │         ↓           │
                  │  ┌──────────────┐   │
                  │  │  EC2 Servers │   │
                  │  │  (Port 5000) │   │
                  │  └──────────────┘   │
                  └──────────┬──────────┘
                             │
                    ┌────────┴────────┐
                    │ Security Group  │
                    │ Only Allows:    │
                    │ - Port 3306     │
                    │ - From EC2 SG   │
                    └────────┬────────┘
                             ↓
                  ┌─────────────────────┐
                  │   PRIVATE SUBNET    │
                  │                     │
                  │  ┌──────────────┐   │
                  │  │ RDS Database │   │
                  │  │ (Port 3306)  │   │
                  │  │ NOT PUBLIC   │   │
                  │  └──────────────┘   │
                  └─────────────────────┘
```

---

## 📂 File Structure on EC2 Servers

```
/opt/debug-marathon/
│
├── backend/                    # Python Flask Application
│   ├── app.py                 # Main application file
│   ├── config.py              # Configuration
│   ├── .env                   # Environment variables ⚠️ SECRETS
│   ├── requirements.txt       # Python dependencies
│   │
│   ├── routes/                # API endpoints
│   │   ├── auth.py           # Login, registration
│   │   ├── contest.py        # Contest management
│   │   ├── admin.py          # Admin functions
│   │   ├── leaderboard.py    # Rankings
│   │   └── proctoring.py     # Anti-cheat
│   │
│   └── utils/                 # Helper functions
│       ├── db.py             # Database operations
│       └── logic.py          # Business logic
│
├── frontend/                   # Static files (HTML/CSS/JS)
│   ├── index.html            # Homepage
│   ├── admin.html            # Admin dashboard
│   ├── participant.html      # Participant view
│   ├── leader_login.html     # Leader login
│   │
│   ├── css/                  # Stylesheets
│   │   ├── main.css
│   │   ├── admin.css
│   │   └── landing.css
│   │
│   ├── js/                   # JavaScript
│   │   ├── main.js
│   │   ├── admin.js
│   │   ├── api.js
│   │   └── proctoring.js
│   │
│   └── assets/               # Images, fonts
│       └── images/
│
└── logs/                      # Application logs
    └── app.log

/etc/nginx/conf.d/
└── debug-marathon.conf        # Nginx configuration

/etc/supervisord.conf          # Process manager config

/var/log/
├── nginx/                     # Web server logs
│   ├── access.log
│   └── error.log
└── supervisor/                # Application logs
    └── debug-marathon.log
```

---

## 🔄 Data Flow: User Registration

```
┌──────────┐
│  BROWSER │
└────┬─────┘
     │ 1. User fills form
     │    POST /api/auth/register
     │    { username, email, password }
     ↓
┌─────────────┐
│    NGINX    │
│  Port 80    │
└──────┬──────┘
       │ 2. Proxy to Gunicorn
       │    localhost:5000
       ↓
┌──────────────┐
│  GUNICORN    │
│  4 Workers   │
└──────┬───────┘
       │ 3. Route to Flask
       │
       ↓
┌──────────────────────┐
│  FLASK (routes/auth.py) │
│                      │
│  4. Validate input   │
│  5. Hash password    │
│  6. Check if exists  │ ────┐
│  7. Insert to DB     │ <───┤
└──────┬───────────────┘     │
       │                     │
       │ 8. SQL Query        ↓
       │                ┌─────────┐
       │                │  MYSQL  │
       │                │   RDS   │
       │                └─────────┘
       │
       ↓ 9. Return response
       │    { success: true, token: "..." }
       │
┌──────┴──────┐
│   BROWSER   │
│             │
│ 10. Store   │
│     token   │
│             │
│ 11. Redirect│
│     to login│
└─────────────┘
```

---

## 🏃 Data Flow: Contest Submission

```
PARTICIPANT submits code
         ↓
┌────────────────────┐
│ Frontend (JS)      │
│ - Capture code     │
│ - Language         │
│ - Problem ID       │
└────────┬───────────┘
         │ POST /api/contest/submit
         ↓
┌────────────────────┐
│ Backend (Flask)    │
│                    │
│ 1. Verify auth     │
│ 2. Check contest   │
│    is active       │
│ 3. Validate code   │
└────────┬───────────┘
         │
         ↓
┌────────────────────┐
│ Database           │
│ INSERT INTO        │
│ submissions        │
│ (user_id, code,    │
│  problem_id,       │
│  timestamp)        │
└────────┬───────────┘
         │
         ↓
┌────────────────────┐
│ Code Execution     │
│ (Future: Judge)    │
│                    │
│ - Run test cases   │
│ - Calculate score  │
└────────┬───────────┘
         │
         ↓
┌────────────────────┐
│ Update DB          │
│ UPDATE submissions │
│ SET status, score  │
└────────┬───────────┘
         │
         ↓
┌────────────────────┐
│ WebSocket          │
│ Broadcast update   │
│ to leaderboard     │
└────────┬───────────┘
         │
         ↓
    ALL USERS see
    updated rankings
```

---

## ⚡ Auto-Scaling Behavior

```
Time        Load    Servers   Action
────────────────────────────────────────────────────
08:00 AM    Low      2        Normal operation
            10%      
                               
09:00 AM    Medium   2        CPU rising
            40%                
                               
10:00 AM    High     2→4      Scale Out Triggered!
            75%                + 2 new servers launched
                               (Takes 2-3 minutes)
                               
10:05 AM    High     4        Load distributed
            50%                
                               
11:00 AM    Peak     4→6      Scale Out Again!
            80%                + 2 more servers
                               
12:00 PM    Peak     6        All hands on deck
            65%                
                               
02:00 PM    Medium   6        Load decreasing
            40%                
                               
03:00 PM    Low      6→4      Scale In
            25%                - 2 servers terminated
                               (After 5 min below threshold)
                               
05:00 PM    Low      4→2      Scale In
            20%                - 2 more servers
                               Back to minimum
```

**Scaling Rules:**
- **Scale Out**: CPU > 70% for 2 minutes → Add 2 servers
- **Scale In**: CPU < 30% for 5 minutes → Remove 2 servers
- **Min**: 2 servers (always running)
- **Max**: 6 servers (cost control)

---

## 🗄️ Database Schema Overview

```
┌────────────────┐
│     users      │
├────────────────┤
│ id (PK)        │
│ username       │
│ email          │
│ password_hash  │
│ role           │◄──────┐
│ created_at     │       │
└────────────────┘       │
                         │
┌────────────────┐       │
│   contests     │       │
├────────────────┤       │
│ id (PK)        │       │
│ title          │       │
│ description    │       │
│ start_time     │       │
│ end_time       │       │
│ status         │       │
│ created_by (FK)├───────┘
└────────┬───────┘
         │
         │
┌────────▼───────┐       ┌────────────────┐
│   problems     │       │  submissions   │
├────────────────┤       ├────────────────┤
│ id (PK)        │◄──────┤ id (PK)        │
│ contest_id (FK)│       │ user_id (FK)   │───┐
│ title          │       │ problem_id (FK)│   │
│ description    │       │ code           │   │
│ test_cases     │       │ language       │   │
│ points         │       │ status         │   │
│ difficulty     │       │ score          │   │
└────────────────┘       │ submitted_at   │   │
                         └────────────────┘   │
                                              │
                         ┌────────────────┐   │
                         │  proctoring_   │   │
                         │  violations    │   │
                         ├────────────────┤   │
                         │ id (PK)        │   │
                         │ user_id (FK)   ├───┘
                         │ contest_id (FK)│
                         │ violation_type │
                         │ timestamp      │
                         │ details        │
                         └────────────────┘
```

---

## 🔐 Authentication Flow

```
┌─────────────────┐
│  User Login     │
│  Page           │
└────────┬────────┘
         │ 1. Enter credentials
         ↓
┌──────────────────┐
│  POST /api/auth/ │
│  login           │
│                  │
│  { username,     │
│    password }    │
└────────┬─────────┘
         │
         ↓
┌──────────────────────┐
│  Backend Validation  │
│                      │
│  1. Find user        │
│  2. Verify password  │
│     (bcrypt hash)    │
│  3. Check role       │
└────────┬─────────────┘
         │
         ↓
┌──────────────────────┐
│  Generate JWT Token  │
│                      │
│  payload = {         │
│    user_id: 123,     │
│    username: "john", │
│    role: "admin",    │
│    exp: timestamp    │
│  }                   │
│                      │
│  token = sign(       │
│    payload,          │
│    SECRET_KEY        │
│  )                   │
└────────┬─────────────┘
         │
         ↓
┌──────────────────────┐
│  Return to Client    │
│                      │
│  {                   │
│    success: true,    │
│    token: "eyJ...",  │
│    user: {...}       │
│  }                   │
└────────┬─────────────┘
         │
         ↓
┌──────────────────────┐
│  Client Storage      │
│                      │
│  localStorage.set(   │
│    'token',          │
│    token             │
│  )                   │
└────────┬─────────────┘
         │
         ↓
┌──────────────────────┐
│  Future Requests     │
│                      │
│  headers: {          │
│    Authorization:    │
│    "Bearer eyJ..."   │
│  }                   │
└──────────────────────┘
         │
         ↓
┌──────────────────────┐
│  Backend Middleware  │
│                      │
│  1. Extract token    │
│  2. Verify signature │
│  3. Check expiry     │
│  4. Add user to      │
│     request context  │
└──────────────────────┘
```

---

## 🌟 Component Responsibilities

```
┌─────────────────────────────────────────────────────┐
│                   LOAD BALANCER                     │
│                                                     │
│  ✓ SSL/TLS termination (HTTPS)                     │
│  ✓ Health checks (every 30 seconds)                │
│  ✓ Traffic distribution (round-robin)              │
│  ✓ Sticky sessions (for WebSocket)                 │
│  ✓ DDoS protection (basic)                         │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                       NGINX                         │
│                                                     │
│  ✓ Serve static files (HTML, CSS, JS, images)      │
│  ✓ Reverse proxy to Gunicorn                       │
│  ✓ Gzip compression                                │
│  ✓ Request buffering                               │
│  ✓ WebSocket upgrade handling                      │
│  ✓ Rate limiting (optional)                        │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                     GUNICORN                        │
│                                                     │
│  ✓ WSGI server (4 worker processes)                │
│  ✓ Process management                              │
│  ✓ Graceful restarts                               │
│  ✓ Worker timeout handling                         │
│  ✓ Load distribution among workers                 │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                       FLASK                         │
│                                                     │
│  ✓ Application logic                               │
│  ✓ Routing (/api/auth, /api/contest, etc.)         │
│  ✓ Request validation                              │
│  ✓ Authentication & authorization                  │
│  ✓ Business logic                                  │
│  ✓ Database queries                                │
│  ✓ Response formatting                             │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                    RDS MYSQL                        │
│                                                     │
│  ✓ Data persistence                                │
│  ✓ Transactions (ACID)                             │
│  ✓ Connection pooling                              │
│  ✓ Automated backups                               │
│  ✓ Point-in-time recovery                          │
│  ✓ Multi-AZ (optional high availability)           │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                    SUPERVISOR                       │
│                                                     │
│  ✓ Keep Gunicorn running                           │
│  ✓ Auto-restart on crash                           │
│  ✓ Log management                                  │
│  ✓ Process monitoring                              │
│  ✓ Control interface (supervisorctl)               │
└─────────────────────────────────────────────────────┘
```

---

## 📈 Monitoring Stack

```
┌──────────────────────────────────────────┐
│           CLOUDWATCH METRICS             │
├──────────────────────────────────────────┤
│                                          │
│  EC2 Metrics:                            │
│  - CPU Utilization (target: <70%)       │
│  - Network In/Out                        │
│  - Disk Read/Write                       │
│                                          │
│  RDS Metrics:                            │
│  - Database Connections (max: 300)      │
│  - CPU Utilization                       │
│  - Free Storage Space                    │
│  - Read/Write Latency                    │
│                                          │
│  ALB Metrics:                            │
│  - Request Count                         │
│  - Target Response Time                  │
│  - Healthy/Unhealthy Host Count          │
│  - HTTP 4xx/5xx Errors                   │
│                                          │
└──────────────────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────────┐
│          CLOUDWATCH ALARMS               │
├──────────────────────────────────────────┤
│                                          │
│  ⚠️  High CPU (>80% for 5 minutes)       │
│  ⚠️  High Error Rate (>5% for 2 mins)    │
│  ⚠️  Database Connections (>250)         │
│  ⚠️  Low Disk Space (<20% free)          │
│  ⚠️  All Targets Unhealthy               │
│                                          │
└──────────────────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────────┐
│               SNS TOPIC                  │
│        (Email/SMS Notifications)         │
└──────────────────────────────────────────┘
```

---

## 🎯 Performance Optimization Points

```
1. BROWSER LEVEL
   ├─ Gzip compression (3-5x smaller)
   ├─ Browser caching (1 year for static)
   ├─ Minified CSS/JS
   └─ Lazy loading images

2. CDN LEVEL (Optional CloudFront)
   ├─ Edge caching globally
   ├─ Reduced latency
   └─ DDoS protection

3. LOAD BALANCER LEVEL
   ├─ Connection reuse
   ├─ Sticky sessions
   └─ Health-based routing

4. NGINX LEVEL
   ├─ Static file serving
   ├─ Request buffering
   ├─ Gzip compression
   └─ Connection pooling

5. APPLICATION LEVEL
   ├─ Efficient queries
   ├─ Pagination
   ├─ Caching (Redis - optional)
   └─ Async operations

6. DATABASE LEVEL
   ├─ Connection pooling (30 per server)
   ├─ Indexed queries
   ├─ Query optimization
   └─ Read replicas (optional)
```

---

## 🔄 Deployment Process

```
┌────────────────┐
│ Code on GitHub │
└────────┬───────┘
         │ 1. git push
         ↓
┌──────────────────┐
│ GitHub Actions   │
│ (CI/CD Pipeline) │
└────────┬─────────┘
         │ 2. Trigger on push
         ↓
┌──────────────────────┐
│ Build & Test         │
│ - Install deps       │
│ - Run tests          │
│ - Package app        │
└────────┬─────────────┘
         │ 3. If tests pass
         ↓
┌──────────────────────────────┐
│ Deploy to All Servers        │
│                              │
│ For each EC2:                │
│ 1. SSH connect               │
│ 2. Pull latest code          │
│ 3. Install dependencies      │
│ 4. Restart Supervisor        │
│ 5. Reload Nginx              │
└────────┬─────────────────────┘
         │ 4. Verify deployment
         ↓
┌──────────────────────┐
│ Health Checks        │
│ - Test /api/health   │
│ - Check all servers  │
│ - Verify responses   │
└────────┬─────────────┘
         │ 5. If all healthy
         ↓
┌──────────────────────┐
│ ✅ Deployment Complete│
│                      │
│ New code is LIVE!    │
└──────────────────────┘
```

---

## 💡 Key Takeaways

### For Beginners:
1. **Load Balancer**: Like a traffic cop, directs users to available servers
2. **Auto Scaling**: Automatically adds/removes servers based on traffic
3. **Database**: Stores all your data (users, contests, submissions)
4. **Nginx**: Fast web server that handles static files
5. **Flask**: Your Python application code

### Production Checklist:
- [ ] At least 2 servers running (high availability)
- [ ] Database backups enabled (daily)
- [ ] Health checks configured (every 30 seconds)
- [ ] Monitoring alerts set up (email notifications)
- [ ] SSL certificate installed (HTTPS)
- [ ] Security groups locked down (minimal access)

---

**📖 For detailed setup instructions, see:**
- [START-HERE.md](START-HERE.md)
- [BEGINNERS-VISUAL-GUIDE.md](BEGINNERS-VISUAL-GUIDE.md)
- [COMPLETE-HOSTING-GUIDE.md](COMPLETE-HOSTING-GUIDE.md)
