#!/bin/bash
set -e

# Debug Marathon - Optimized UserData Script for Stability and Performance
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Debug Marathon Setup (OPTIMIZED) ==="
date

# 1. Install Dependencies
echo "[1/9] Installing System Dependencies..."
yum update -y
yum install -y nginx python3-pip unzip aws-cli jq java-1.8.0-openjdk-devel

# 2. Install Python Packages
echo "[2/9] Installing Python packages..."
# Using --no-cache-dir to save space and ensure fresh fetch
pip3 install --no-cache-dir supervisor Flask==3.0.0 flask-cors flask-socketio python-dotenv gunicorn mysql-connector-python PyJWT eventlet

# 3. Create Directories
echo "[3/9] Creating project structure..."
mkdir -p /opt/debug-marathon/backend /opt/debug-marathon/frontend
mkdir -p /etc/nginx/conf.d
mkdir -p /var/log/supervisor

# 4. Download Code Assets (Using exact paths from previous working setup)
echo "[4/9] Downloading Application Code..."

# Backend
cd /opt/debug-marathon/backend
aws s3 cp s3://debug-marathon-assets-052150906633/backend.zip /tmp/backend.zip --region ap-southeast-1 || {
    echo "CRITICAL: Failed to download backend from S3"
    exit 1
}
unzip -o /tmp/backend.zip

# Frontend
cd /opt/debug-marathon/frontend
aws s3 cp s3://debug-marathon-assets-052150906633/frontend.zip /tmp/frontend.zip --region ap-southeast-1 || {
    echo "CRITICAL: Failed to download frontend from S3"
    exit 1
}
unzip -o /tmp/frontend.zip

# 5. APPLY CRITICAL FIXES (The "Perfect" Code)
echo "[5/9] Applying Critical Patches..."

# Fix DB Connection (Prevent Connect/Disconnect loops)
cat > /opt/debug-marathon/backend/db_connection.py << 'PYTHONEOF'
import logging
import os
import configparser
from dotenv import load_dotenv

load_dotenv()

# Configure Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("DatabaseManager")

USE_SQLITE = False

try:
    import mysql.connector
    from mysql.connector import pooling, Error
except ImportError:
    logger.warning("mysql.connector not found. Falling back to SQLite.")
    USE_SQLITE = True

class MySQLManager:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(MySQLManager, cls).__new__(cls)
            cls._instance._initialize_pool()
        return cls._instance

    def _initialize_pool(self, database=None):
        self.pid = os.getpid()
        try:
            config = configparser.ConfigParser()
            config_path = os.path.join(os.path.dirname(__file__), 'db_config.ini')
            
            base_config = {
                "host": os.getenv('DB_HOST', 'localhost'),
                "port": int(os.getenv('DB_PORT', 3306)),
                "user": os.getenv('DB_USER', 'root'),
                "password": os.getenv('DB_PASSWORD', ''),
                "charset": "utf8mb4",
                "collation": "utf8mb4_unicode_ci"
            }
            
            if os.path.exists(config_path):
                config.read(config_path)
                if 'mysql' in config:
                    read_config = dict(config['mysql'])
                    for key in ['pool_name', 'pool_size', 'pool_reset_session']:
                        read_config.pop(key, None)
                    base_config.update(read_config)

            if os.getenv('DB_HOST'): base_config['host'] = os.getenv('DB_HOST')
            if os.getenv('DB_USER'): base_config['user'] = os.getenv('DB_USER')
            if os.getenv('DB_PASSWORD') is not None: base_config['password'] = os.getenv('DB_PASSWORD')
            if os.getenv('DB_NAME'): base_config['database'] = os.getenv('DB_NAME')
            
            target_db = database or base_config.pop('database', 'debug_marathon_v3')

            try:
                full_config = base_config.copy()
                full_config['database'] = target_db
                # POOL SIZE: optimized for t3.micro/small (max 60-150 connections total)
                # 30 per worker is aggressive if we have many instances. Reduced to 20.
                self.pool = mysql.connector.pooling.MySQLConnectionPool(
                    pool_name=f"debug_marathon_pool_{self.pid}",
                    pool_size=15,
                    pool_reset_session=True,
                    **full_config
                )
                logger.info(f"Connection pool initialized for PID {self.pid}.")
            except Error as e:
                if e.errno == 1049: 
                    logger.warning(f"Database '{target_db}' not found. Connecting to server only.")
                    base_config.pop('database', None)
                    self.pool = mysql.connector.pooling.MySQLConnectionPool(
                        pool_name=f"debug_marathon_pool_{self.pid}",
                        pool_size=15,
                        pool_reset_session=True,
                        **base_config
                    )
                else:
                    raise
        except Error as e:
            logger.error(f"Error initializing connection pool: {e}")
            raise

    def get_connection(self):
        # Fork detection
        if getattr(self, 'pid', None) != os.getpid():
            logger.warning(f"Fork detected (Parent PID: {getattr(self, 'pid', '?')} -> Child PID: {os.getpid()}). Re-initializing pool.")
            self._initialize_pool()

        try:
            conn = self.pool.get_connection()
            if conn.is_connected():
                return conn
            else:
                try:
                    conn.reconnect(attempts=3, delay=2)
                    return conn
                except:
                    return None
        except Error as e:
            logger.error(f"Failed to get connection from pool: {e}")
            return None

    def execute_query(self, query, params=None):
        conn = self.get_connection()
        if not conn: return None
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(query, params or ())
            result = cursor.fetchall()
            return result
        except Error as e:
            logger.error(f"SELECT Query failed: {e}\nQuery: {query}")
            return None
        finally:
            if cursor: try: cursor.close(); except: pass
            if conn: try: conn.close(); except: pass

    def execute_update(self, query, params=None):
        conn = self.get_connection()
        if not conn: return False
        cursor = conn.cursor()
        try:
            cursor.execute(query, params or ())
            conn.commit()
            return {"last_id": cursor.lastrowid, "affected": cursor.rowcount}
        except Error as e:
            conn.rollback()
            logger.error(f"UPDATE Query failed: {e}\nQuery: {query}")
            return False
        finally:
            if cursor: try: cursor.close(); except: pass
            if conn: try: conn.close(); except: pass

    def upsert(self, table, data, conflict_keys):
        keys = list(data.keys())
        columns = ', '.join(keys)
        placeholders = ', '.join(['%s'] * len(keys))
        update_clause = ', '.join([f"{k}=VALUES({k})" for k in keys if k not in conflict_keys])
        if not update_clause:
            sql = f"INSERT IGNORE INTO {table} ({columns}) VALUES ({placeholders})"
        else:
            sql = f"INSERT INTO {table} ({columns}) VALUES ({placeholders}) ON DUPLICATE KEY UPDATE {update_clause}"
        return self.execute_update(sql, tuple(data.values()))

try:
    if not USE_SQLITE:
        _temp = MySQLManager()
    db_manager = _temp
except Exception as e:
    logger.warning(f"MySQL Connection Failed ({e}). Switching to SQLite.")
    from db_sqlite import sqlite_manager
    db_manager = sqlite_manager
PYTHONEOF

# 6. Configure Environment
echo "[6/9] Configuring Environment..."
# WARNING: YOU MUST REPLACE THESE VALUES BEFORE DEPLOYMENT
cat > /opt/debug-marathon/backend/.env << 'ENVEOF'
DB_HOST=debug-marathon-db.cbs2qwqei97e.ap-southeast-1.rds.amazonaws.com
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=YOUR_DB_PASSWORD_HERE
DB_NAME=debug_marathon_v3
FLASK_ENV=production
FLASK_DEBUG=False
SECRET_KEY=YOUR_SECRET_KEY_HERE
FRONTEND_URL=http://debug-marathon-alb-1798040122.ap-southeast-1.elb.amazonaws.com
ENVEOF

# 7. Configure Nginx (With WebSocket Support)
echo "[7/9] Configuring Nginx..."
cat > /etc/nginx/conf.d/debug-marathon.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;
    
    # Increase buffer size for large headers/cookies
    large_client_header_buffers 4 32k;

    # Static Assets (Performance)
    location /css/ { alias /opt/debug-marathon/frontend/css/; expires 1d; access_log off; }
    location /js/ { alias /opt/debug-marathon/frontend/js/; expires 1d; access_log off; }
    location /assets/ { alias /opt/debug-marathon/frontend/assets/; expires 1d; access_log off; }

    # WebSocket Support (Socket.IO)
    location /socket.io {
        proxy_pass http://127.0.0.1:5000/socket.io;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
    }

    # API & App Proxy
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINXEOF

rm -f /etc/nginx/conf.d/default.conf

# 8. Configure Supervisor (Worker Optimized)
echo "[8/9] Configuring Supervisor..."
mkdir -p /etc/supervisord.d

cat > /etc/supervisord.conf << 'SUPEOF'
[supervisord]
nodaemon=false
logfile=/var/log/supervisor/supervisord.log
[supervisorctl]
serverurl=unix:///var/run/supervisor.sock
[unix_http_server]
file=/var/run/supervisor.sock
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
[include]
files = /etc/supervisord.d/*.ini
SUPEOF

cat > /etc/supervisord.d/debug-marathon.ini << 'APPEOF'
[program:debug-marathon]
directory=/opt/debug-marathon/backend
# WORKERS = 1 to prevent socket.io split-brain issues without Redis
# THREADS = 100 to handle concurrency
command=/usr/local/bin/gunicorn --workers 1 --threads 100 --bind 127.0.0.1:5000 --timeout 120 --worker-class gthread "app:create_app()"
autostart=true
autorestart=true
stderr_logfile=/var/log/debug-marathon.log
stdout_logfile=/var/log/debug-marathon.log
APPEOF

# 9. Start Services
echo "[9/9] Starting Services..."
systemctl enable nginx
systemctl restart nginx
/usr/local/bin/supervisord -c /etc/supervisord.conf &

# Permission Fix
chown -R ec2-user:ec2-user /opt/debug-marathon

echo "=== Optimized Setup Complete ==="
date
