import os
import sys
from db_connection import db_manager

def initialize():
    print("🚀 Starting Database Initialization...")
    
    # Path to the SQL file
    schema_path = os.path.join(os.path.dirname(__file__), 'database_setup_postgres.sql')
    
    if not os.path.exists(schema_path):
        print(f"❌ Error: Schema file not found at {schema_path}")
        return

    print(f"📖 Reading schema from {schema_path}...")
    
    try:
        success = db_manager.init_database(schema_path)
        if success:
            print("✅ Database initialized successfully!")
            print("🎉 You can now log in with username 'admin' and the default hash.")
        else:
            print("❌ Database initialization failed. Check logs for details.")
    except Exception as e:
        print(f"❌ An unexpected error occurred: {e}")

if __name__ == "__main__":
    if not os.getenv('DATABASE_URL'):
        print("⚠️  Warning: DATABASE_URL not found in environment.")
        print("This script is intended to be run inside the Render/Railway environment.")
    
    initialize()
