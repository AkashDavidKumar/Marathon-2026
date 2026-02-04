
from db_connection import db_manager
import json

def check_contests():
    print("Contests:")
    contests = db_manager.execute_query("SELECT * FROM contests")
    for c in contests:
        print(f"ID: {c['contest_id']}, Name: {c['contest_name']}, Status: {c['status']}")
    
    print("\nRounds:")
    rounds = db_manager.execute_query("SELECT * FROM rounds")
    for r in rounds:
        print(f"ID: {r['round_id']}, Number: {r['round_number']}, Status: {r['status']}, Contest: {r['contest_id']}")

    print("\nParticipant Level Stats:")
    stats = db_manager.execute_query("SELECT * FROM participant_level_stats ORDER BY level DESC LIMIT 10")
    for s in stats:
        print(f"User: {s['user_id']}, Level: {s['level']}, Status: {s['status']}, Start: {s['start_time']}")

if __name__ == "__main__":
    check_contests()
