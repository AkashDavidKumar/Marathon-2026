#!/usr/bin/env python3
"""
Quick SQL Query Runner for RDS
Usage: python run_query.py "SELECT * FROM users LIMIT 5"
"""

import sys
from db_connection import db_manager

def run_query(sql):
    """Execute a SQL query and print results"""
    try:
        # Determine if it's a SELECT or UPDATE/INSERT/DELETE
        sql_upper = sql.strip().upper()
        
        if sql_upper.startswith('SELECT') or sql_upper.startswith('SHOW') or sql_upper.startswith('DESCRIBE'):
            # Query that returns results
            results = db_manager.execute_query(sql)
            
            if not results:
                print("No results returned.")
                return
            
            # Print results in a formatted way
            print(f"\n✅ Query executed successfully. {len(results)} row(s) returned.\n")
            
            # Print column headers
            if results:
                headers = list(results[0].keys())
                print(" | ".join(headers))
                print("-" * (sum(len(h) for h in headers) + 3 * len(headers)))
                
                # Print rows
                for row in results:
                    print(" | ".join(str(row[h]) for h in headers))
            
        else:
            # UPDATE, INSERT, DELETE, etc.
            result = db_manager.execute_update(sql)
            
            if result:
                affected = result.get('affected_rows', 'unknown')
                print(f"\n✅ Query executed successfully. {affected} row(s) affected.")
                if 'last_id' in result:
                    print(f"   Last inserted ID: {result['last_id']}")
            else:
                print("\n✅ Query executed successfully.")
                
    except Exception as e:
        print(f"\n❌ Error executing query: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python run_query.py \"YOUR SQL QUERY\"")
        print("\nExamples:")
        print('  python run_query.py "SELECT * FROM users LIMIT 5"')
        print('  python run_query.py "UPDATE users SET role=\'admin\' WHERE user_id=1"')
        print('  python run_query.py "SHOW TABLES"')
        sys.exit(1)
    
    query = " ".join(sys.argv[1:])
    print(f"\n🔍 Executing query: {query}\n")
    run_query(query)
