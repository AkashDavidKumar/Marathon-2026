# db_connection_universal.py
# Universal Database Manager supporting MySQL and PostgreSQL
# Auto-detects based on DATABASE_URL environment variable

import logging
import os
from dotenv import load_dotenv

load_dotenv()

# Configure Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("DatabaseManager")

# Detect database type from environment
DATABASE_URL = os.getenv('DATABASE_URL')  # PostgreSQL URL from Railway/Render
USE_POSTGRES = DATABASE_URL and DATABASE_URL.startswith('postgres')

if USE_POSTGRES:
    logger.info("🐘 Using PostgreSQL (detected DATABASE_URL)")
    try:
        import psycopg2
        from psycopg2.extras import RealDictCursor
        from psycopg2 import pool
    except ImportError:
        logger.error("psycopg2 not installed! Run: pip install psycopg2-binary")
        raise
else:
    logger.info("🐬 Using MySQL (local/AWS)")
    try:
        import mysql.connector
        from mysql.connector import pooling, Error
    except ImportError:
        logger.error("mysql-connector-python not installed!")
        raise


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
            self.pool = psycopg2.pool.SimpleConnectionPool(
                1, 20,  # min and max connections
                DATABASE_URL
            )
            logger.info(f"✅ PostgreSQL connection pool initialized (1-20 connections)")
        except Exception as e:
            logger.error(f"❌ Failed to initialize PostgreSQL pool: {e}")
            raise

    def get_connection(self):
        try:
            return self.pool.getconn()
        except Exception as e:
            logger.error(f"Failed to get PostgreSQL connection: {e}")
            return None

    def return_connection(self, conn):
        """Return connection to pool"""
        if conn:
            self.pool.putconn(conn)

    def execute_query(self, query, params=None):
        """Execute SELECT query and return results as list of dicts"""
        conn = self.get_connection()
        if not conn:
            return None
        
        cursor = None
        try:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute(query, params or ())
            result = cursor.fetchall()
            # Convert RealDictRow to regular dict
            return [dict(row) for row in result]
        except Exception as e:
            logger.error(f"SELECT Query failed: {e}\nQuery: {query}")
            return None
        finally:
            if cursor:
                cursor.close()
            self.return_connection(conn)

    def execute_update(self, query, params=None):
        """Execute INSERT/UPDATE/DELETE query"""
        conn = self.get_connection()
        if not conn:
            return False
        
        cursor = None
        try:
            cursor = conn.cursor()
            cursor.execute(query, params or ())
            conn.commit()
            return {
                "last_id": cursor.lastrowid if hasattr(cursor, 'lastrowid') else None,
                "affected": cursor.rowcount
            }
        except Exception as e:
            conn.rollback()
            logger.error(f"UPDATE Query failed: {e}\nQuery: {query}")
            return False
        finally:
            if cursor:
                cursor.close()
            self.return_connection(conn)

    def upsert(self, table, data, conflict_keys):
        """PostgreSQL upsert using ON CONFLICT"""
        keys = list(data.keys())
        columns = ', '.join(keys)
        placeholders = ', '.join(['%s'] * len(keys))
        
        conflict_clause = ', '.join(conflict_keys)
        update_clause = ', '.join([f"{k}=EXCLUDED.{k}" for k in keys if k not in conflict_keys])
        
        if not update_clause:
            # Just INSERT with DO NOTHING
            sql = f"INSERT INTO {table} ({columns}) VALUES ({placeholders}) ON CONFLICT ({conflict_clause}) DO NOTHING"
        else:
            sql = f"INSERT INTO {table} ({columns}) VALUES ({placeholders}) ON CONFLICT ({conflict_clause}) DO UPDATE SET {update_clause}"
        
        vals = tuple(data.values())
        return self.execute_update(sql, vals)


class MySQLManager:
    """MySQL Database Manager for local/AWS deployments"""
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(MySQLManager, cls).__new__(cls)
            cls._instance._initialize_pool()
        return cls._instance

    def _initialize_pool(self):
        self.pid = os.getpid()
        try:
            base_config = {
                "host": os.getenv('DB_HOST', 'localhost'),
                "port": int(os.getenv('DB_PORT', 3306)),
                "user": os.getenv('DB_USER', 'root'),
                "password": os.getenv('DB_PASSWORD', ''),
                "database": os.getenv('DB_NAME', 'debug_marathon_v3'),
                "charset": "utf8mb4",
                "collation": "utf8mb4_unicode_ci"
            }
            
            self.pool = mysql.connector.pooling.MySQLConnectionPool(
                pool_name=f"marathon_pool_{self.pid}",
                pool_size=20,
                pool_reset_session=True,
                connection_timeout=10,
                autocommit=False,
                use_pure=False,
                **base_config
            )
            logger.info(f"✅ MySQL connection pool initialized (20 connections)")
        except Error as e:
            logger.error(f"❌ Failed to initialize MySQL pool: {e}")
            raise

    def get_connection(self):
        if getattr(self, 'pid', None) != os.getpid():
            logger.warning(f"Fork detected. Re-initializing pool.")
            self._initialize_pool()

        try:
            conn = self.pool.get_connection()
            if conn.is_connected():
                try:
                    conn.ping(reconnect=True, attempts=2, delay=1)
                except Error:
                    logger.warning("Connection ping failed, attempting reconnect...")
                    conn.reconnect(attempts=2, delay=1)
                return conn
            else:
                conn.reconnect(attempts=2, delay=1)
                return conn
        except Error as e:
            logger.error(f"Failed to get connection from pool: {e}")
            return None

    def execute_query(self, query, params=None):
        conn = self.get_connection()
        if not conn:
            return None
        
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(query, params or ())
            result = cursor.fetchall()
            return result
        except Error as e:
            logger.error(f"SELECT Query failed: {e}\nQuery: {query}")
            return None
        finally:
            if cursor:
                cursor.close()
            if conn:
                conn.close()

    def execute_update(self, query, params=None):
        conn = self.get_connection()
        if not conn:
            return False
        
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
            if cursor:
                cursor.close()
            if conn:
                conn.close()

    def upsert(self, table, data, conflict_keys):
        """MySQL upsert using ON DUPLICATE KEY UPDATE"""
        keys = list(data.keys())
        columns = ', '.join(keys)
        placeholders = ', '.join(['%s'] * len(keys))
        
        update_clause = ', '.join([f"{k}=VALUES({k})" for k in keys if k not in conflict_keys])
        
        if not update_clause:
            sql = f"INSERT IGNORE INTO {table} ({columns}) VALUES ({placeholders})"
        else:
            sql = f"INSERT INTO {table} ({columns}) VALUES ({placeholders}) ON DUPLICATE KEY UPDATE {update_clause}"
        
        vals = tuple(data.values())
        return self.execute_update(sql, vals)


# Factory: Auto-select database manager
if USE_POSTGRES:
    db_manager = PostgreSQLManager()
    logger.info("🚀 Using PostgreSQL Manager")
else:
    db_manager = MySQLManager()
    logger.info("🚀 Using MySQL Manager")
