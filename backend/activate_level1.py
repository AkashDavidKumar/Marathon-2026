#!/usr/bin/env python3
"""
Quick script to activate Level 1 for the contest
Run this on EC2: sudo python3 activate_level1.py
"""

from db_connection import db_manager

def activate_level_1():
    """Set Level 1 to active status"""
    try:
        # Update Level 1 to active
        query = "UPDATE rounds SET status='active' WHERE contest_id=1 AND round_number=1"
        result = db_manager.execute_update(query)
        
        print("✅ Level 1 activated successfully!")
        
        # Verify
        verify_query = "SELECT round_number, round_name, status FROM rounds WHERE contest_id=1 ORDER BY round_number"
        rounds = db_manager.execute_query(verify_query)
        
        print("\n📊 Current Round Statuses:")
        print("-" * 50)
        for r in rounds:
            status_icon = "🟢" if r['status'] == 'active' else "🔴"
            print(f"{status_icon} Level {r['round_number']}: {r['round_name']} - {r['status'].upper()}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("🚀 Activating Level 1...\n")
    activate_level_1()
