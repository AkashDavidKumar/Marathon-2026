"""
Test script to verify the admin dashboard stats endpoint fix
Run this after starting the backend server to verify the fix works
"""

import requests
import json

# Configuration
BASE_URL = "http://localhost:5000"  # Adjust if your backend runs on a different port
CONTEST_ID = 1

def test_stats_endpoint():
    """Test the /contest/<id>/stats endpoint"""
    print("=" * 60)
    print("Testing Admin Dashboard Stats Endpoint")
    print("=" * 60)
    
    url = f"{BASE_URL}/contest/{CONTEST_ID}/stats"
    
    try:
        print(f"\n1. Making GET request to: {url}")
        response = requests.get(url)
        
        print(f"   Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"\n2. Response Data:")
            print(json.dumps(data, indent=2))
            
            # Verify all required fields exist
            required_fields = [
                'total_participants',
                'active_participants',
                'violations_detected',
                'questions_solved'
            ]
            
            print(f"\n3. Validation:")
            all_valid = True
            for field in required_fields:
                if field in data:
                    value = data[field]
                    is_number = isinstance(value, (int, float))
                    status = "✓" if is_number else "✗"
                    print(f"   {status} {field}: {value} (type: {type(value).__name__})")
                    if not is_number:
                        all_valid = False
                else:
                    print(f"   ✗ {field}: MISSING")
                    all_valid = False
            
            if all_valid:
                print(f"\n✓ SUCCESS: All stats are valid numbers!")
                print(f"\nSummary:")
                print(f"  - Total Participants: {data['total_participants']}")
                print(f"  - Active Participants: {data['active_participants']}")
                print(f"  - Violations Detected: {data['violations_detected']}")
                print(f"  - Questions Solved: {data['questions_solved']}")
                return True
            else:
                print(f"\n✗ FAILED: Some stats are invalid or missing")
                return False
        else:
            print(f"\n✗ FAILED: HTTP {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"\n✗ ERROR: Could not connect to {BASE_URL}")
        print(f"   Make sure the backend server is running!")
        return False
    except Exception as e:
        print(f"\n✗ ERROR: {str(e)}")
        return False

def test_contests_endpoint():
    """Test the /contest endpoint to verify contests exist"""
    print("\n" + "=" * 60)
    print("Testing Contests Endpoint")
    print("=" * 60)
    
    url = f"{BASE_URL}/contest"
    
    try:
        print(f"\n1. Making GET request to: {url}")
        response = requests.get(url)
        
        print(f"   Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            contests = data.get('contests', [])
            print(f"\n2. Found {len(contests)} contest(s)")
            
            if contests:
                for i, contest in enumerate(contests, 1):
                    print(f"\n   Contest {i}:")
                    print(f"     ID: {contest.get('id')}")
                    print(f"     Title: {contest.get('title')}")
                    print(f"     Status: {contest.get('status')}")
            else:
                print(f"\n   ⚠ WARNING: No contests found in database")
                print(f"   The stats endpoint will use fallback logic")
            
            return True
        else:
            print(f"\n✗ FAILED: HTTP {response.status_code}")
            return False
            
    except Exception as e:
        print(f"\n✗ ERROR: {str(e)}")
        return False

if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("ADMIN DASHBOARD FIX VERIFICATION TEST")
    print("=" * 60)
    print(f"\nBackend URL: {BASE_URL}")
    print(f"Contest ID: {CONTEST_ID}")
    
    # Test contests endpoint first
    contests_ok = test_contests_endpoint()
    
    # Test stats endpoint
    stats_ok = test_stats_endpoint()
    
    # Final summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    print(f"Contests Endpoint: {'✓ PASS' if contests_ok else '✗ FAIL'}")
    print(f"Stats Endpoint: {'✓ PASS' if stats_ok else '✗ FAIL'}")
    
    if contests_ok and stats_ok:
        print(f"\n✓ ALL TESTS PASSED!")
        print(f"\nThe admin dashboard should now load correctly.")
    else:
        print(f"\n✗ SOME TESTS FAILED")
        print(f"\nPlease check:")
        print(f"  1. Backend server is running")
        print(f"  2. Database connection is working")
        print(f"  3. The fixes were applied correctly")
    
    print("=" * 60)
