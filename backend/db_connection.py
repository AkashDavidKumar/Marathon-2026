
# db_connection.py
# Universal Database Manager supporting MySQL, PostgreSQL, and SQLite fallback
# Auto-detects based on DATABASE_URL environment variable

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

# --- AUTO-DETECTION ---
# Look for connection strings in multiple common env vars
DATABASE_URL = os.getenv('DATABASE_URL') or os.getenv('INTERNAL_DATABASE_URL') or os.getenv('DB_URL')
USE_POSTGRES = DATABASE_URL and (DATABASE_URL.startswith('postgres') or DATABASE_URL.startswith('postgresql'))
USE_SQLITE = os.getenv('USE_SQLITE', 'False') == 'True'

if not USE_POSTGRES:
    logger.info(f"PostgreSQL not detected (DATABASE_URL is {'empty' if not DATABASE_URL else 'invalid'}).")

# Check dependencies
try:
    if USE_POSTGRES:
        import psycopg2
        from psycopg2.extras import RealDictCursor
        from psycopg2 import pool
        logger.info("🐘 PostgreSQL driver (psycopg2) loaded successfully.")
    else:
        import mysql.connector
        from mysql.connector import pooling, Error
except ImportError as e:
    logger.warning(f"❌ DB driver not found ({e}). Falling back to SQLite.")
    USE_POSTGRES = False # Force fallback if driver is missing
    USE_SQLITE = True

class PostgreSQLManager:
    """PostgreSQL Database Manager for Railway/Render deployments"""
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(PostgreSQLManager, cls).__new__(cls)
            cls._instance._initialize_pool()
        return cls._instance

    def _initialize_pool(self):
        try:
            # Handle Render/Railway 'postgres://' vs 'postgresql://'
            conn_url = DATABASE_URL
            if conn_url.startswith('postgres://'):
                conn_url = conn_url.replace('postgres://', 'postgresql://', 1)
                
            self.pool = psycopg2.pool.SimpleConnectionPool(
                1, 20, # min and max connections
                conn_url
            )
            logger.info("✅ PostgreSQL connection pool initialized (1-20 connections)")
        except Exception as e:
            logger.error(f"❌ Failed to initialize PostgreSQL pool: {e}")
            raise

    def get_connection(self):
        try:
            return self.pool.getconn()
        except Exception as e:
            logger.error(f"Failed to get PostgreSQL connection: {e}")
            return None

    def execute_query(self, query, params=None):
        conn = self.get_connection()
        if not conn: return None
        
        cursor = None
        try:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute(query, params or ())
            result = cursor.fetchall()
            return [dict(row) for row in result]
        except Exception as e:
            logger.error(f"PostgreSQL SELECT failed: {e}\nQuery: {query}")
            return None
        finally:
            if cursor: cursor.close()
            if conn: self.pool.putconn(conn)

    def execute_update(self, query, params=None):
        conn = self.get_connection()
        if not conn: return False
        
        cursor = None
        try:
            cursor = conn.cursor()
            cursor.execute(query, params or ())
            conn.commit()
            # PostgreSQL doesn't have lastrowid in the same way, but often returns it via RETURNING
            # This is a generic wrapper, so we do our best
            return {"last_id": None, "affected": cursor.rowcount}
        except Exception as e:
            if conn: conn.rollback()
            logger.error(f"PostgreSQL UPDATE failed: {e}\nQuery: {query}")
            return False
        finally:
            if cursor: cursor.close()
            if conn: self.pool.putconn(conn)

    def init_database(self, schema_file):
        conn = self.get_connection()
        if not conn: return False
        cursor = conn.cursor()
        try:
            with open(schema_file, 'r') as f:
                sql = f.read()
            cursor.execute(sql)
            conn.commit()
            return True
        except Exception as e:
            logger.error(f"PostgreSQL Init failed: {e}")
            return False
        finally:
            cursor.close()
            self.pool.putconn(conn)

class MySQLManager:
    """MySQL Database Manager for local/AWS deployments"""
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
                self.pool = mysql.connector.pooling.MySQLConnectionPool(
                    pool_name=f"marathon_pool_{self.pid}",
                    pool_size=20,
                    pool_reset_session=True,
                    connection_timeout=10,
                    autocommit=False,
                    use_pure=False,
                    **full_config
                )
                logger.info(f"✅ MySQL pool initialized with database '{target_db}'")
            except Error as e:
                if e.errno == 1049:
                    logger.warning(f"Database '{target_db}' not found. Connecting to server.")
                    self.pool = mysql.connector.pooling.MySQLConnectionPool(
                        pool_name=f"marathon_pool_{self.pid}",
                        pool_size=20,
                        **base_config
                    )
                else: raise
        except Error as e:
            logger.error(f"Error initializing MySQL pool: {e}")
            raise

    def get_connection(self):
        if getattr(self, 'pid', None) != os.getpid():
            self._initialize_pool()
        try:
            conn = self.pool.get_connection()
            if conn.is_connected():
                conn.ping(reconnect=True)
                return conn
            return None
        except Error: return None

    def execute_query(self, query, params=None):
        conn = self.get_connection()
        if not conn: return None
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(query, params or ())
            return cursor.fetchall()
        except Error as e:
            logger.error(f"MySQL SELECT failed: {e}")
            return None
        finally:
            if cursor: cursor.close()
            if conn: conn.close()

    def execute_update(self, query, params=None):
        conn = self.get_connection()
        if not conn: return False
        cursor = conn.cursor()
        try:
            cursor.execute(query, params or ())
            conn.commit()
            return {"last_id": cursor.lastrowid, "affected": cursor.rowcount}
        except Error as e:
            if conn: conn.rollback()
            logger.error(f"MySQL UPDATE failed: {e}")
            return False
        finally:
            if cursor: cursor.close()
            if conn: conn.close()

    def init_database(self, schema_file):
        conn = self.get_connection()
        if not conn: return False
        cursor = conn.cursor()
        try:
            with open(schema_file, 'r') as f:
                sql = f.read()
            for statement in sql.split(';'):
                if statement.strip():
                    cursor.execute(statement)
            conn.commit()
            return True
        except Error as e:
            logger.error(f"MySQL Init failed: {e}")
            return False
        finally:
            cursor.close()
            conn.close()

# --- FACTORY SELECTION ---
try:
    if USE_POSTGRES:
        db_manager = PostgreSQLManager()
    elif USE_SQLITE:
        from db_sqlite import sqlite_manager
        db_manager = sqlite_manager
    else:
        db_manager = MySQLManager()
except Exception as e:
    logger.warning(f"Preferred DB failed ({e}). Switching to SQLite fallback.")
    from db_sqlite import sqlite_manager
    db_manager = sqlite_manager
