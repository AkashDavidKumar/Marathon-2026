#!/usr/bin/env python3
"""
Performance Testing Script for Debug Marathon Application
Tests the application under 350+ concurrent user load
"""

import asyncio
import aiohttp
import time
import json
import statistics
from datetime import datetime
import random
import string

class LoadTester:
    def __init__(self, base_url, num_users=350):
        self.base_url = base_url.rstrip('/')
        self.num_users = num_users
        self.results = []
        self.session = None
        
    async def create_session(self):
        connector = aiohttp.TCPConnector(limit=500, limit_per_host=100)
        timeout = aiohttp.ClientTimeout(total=30)
        self.session = aiohttp.ClientSession(connector=connector, timeout=timeout)
    
    async def close_session(self):
        if self.session:
            await self.session.close()
    
    def generate_random_user(self):
        """Generate random user data for testing"""
        username = ''.join(random.choices(string.ascii_lowercase, k=8))
        email = f"{username}@test.com"
        return {
            'username': username,
            'email': email,
            'password': 'test123456',
            'full_name': f'Test User {username.title()}'
        }
    
    async def test_endpoint(self, method, endpoint, data=None, expected_status=200):
        """Test a single endpoint and record response time"""
        start_time = time.time()
        
        try:
            if method.upper() == 'GET':
                async with self.session.get(f"{self.base_url}{endpoint}") as response:
                    status = response.status
                    content = await response.text()
            elif method.upper() == 'POST':
                headers = {'Content-Type': 'application/json'} if data else {}
                json_data = json.dumps(data) if data else None
                async with self.session.post(f"{self.base_url}{endpoint}", data=json_data, headers=headers) as response:
                    status = response.status
                    content = await response.text()
            
            response_time = time.time() - start_time
            
            result = {
                'endpoint': endpoint,
                'method': method,
                'status': status,
                'response_time': response_time,
                'success': status == expected_status,
                'timestamp': datetime.now().isoformat()
            }
            
            return result
            
        except Exception as e:
            response_time = time.time() - start_time
            return {
                'endpoint': endpoint,
                'method': method,
                'status': 0,
                'response_time': response_time,
                'success': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    async def simulate_user_journey(self, user_id):
        """Simulate a complete user journey"""
        journey_results = []
        
        # 1. Health check
        result = await self.test_endpoint('GET', '/api/health')
        journey_results.append(result)
        
        # 2. Load homepage
        result = await self.test_endpoint('GET', '/')
        journey_results.append(result)
        
        # 3. Login (Participant) - User ID matching generic format "PART{id}"
        # We assume IDs 1-350 exist or we generate a random valid looking one if strict checking is off
        # For load testing, we'll try a generic ID or skip if we can't guess. 
        # Let's use "PART001" for all to test concurrency on hot rows, or random.
        pid = f"PART{random.randint(1, 100):03d}"
        login_data = {'participant_id': pid}
        
        result = await self.test_endpoint('POST', '/api/auth/participant/login', login_data)
        journey_results.append(result)
        
        # 4. Get contests
        result = await self.test_endpoint('GET', '/api/contest')
        journey_results.append(result)
        
        # 5. Get leaderboard
        result = await self.test_endpoint('GET', '/api/leaderboard')
        journey_results.append(result)
        
        # Add small delay to simulate user thinking time
        await asyncio.sleep(random.uniform(0.1, 0.5))
        
        return journey_results
    
    async def run_concurrent_test(self):
        """Run concurrent user simulation"""
        print(f"🚀 Starting load test with {self.num_users} concurrent users")
        print(f"Target URL: {self.base_url}")
        print("=" * 60)
        
        await self.create_session()
        
        start_time = time.time()
        
        # Create tasks for all users
        tasks = [self.simulate_user_journey(i) for i in range(self.num_users)]
        
        # Run all tasks concurrently
        all_results = await asyncio.gather(*tasks, return_exceptions=True)
        
        total_time = time.time() - start_time
        
        await self.close_session()
        
        # Process results
        successful_journeys = 0
        all_requests = []
        
        for i, journey_result in enumerate(all_results):
            if isinstance(journey_result, Exception):
                print(f"❌ User {i} journey failed: {journey_result}")
                continue
            
            journey_success = True
            for request_result in journey_result:
                all_requests.append(request_result)
                if not request_result['success']:
                    journey_success = False
            
            if journey_success:
                successful_journeys += 1
        
        return {
            'total_time': total_time,
            'total_users': self.num_users,
            'successful_journeys': successful_journeys,
            'success_rate': (successful_journeys / self.num_users) * 100,
            'all_requests': all_requests
        }
    
    def analyze_results(self, test_results):
        """Analyze test results and generate report"""
        all_requests = test_results['all_requests']
        
        if not all_requests:
            print("❌ No request data to analyze")
            return
        
        # Calculate statistics
        response_times = [r['response_time'] for r in all_requests if r['success']]
        failed_requests = [r for r in all_requests if not r['success']]
        
        # Endpoint performance
        endpoint_stats = {}
        for request in all_requests:
            endpoint = request['endpoint']
            if endpoint not in endpoint_stats:
                endpoint_stats[endpoint] = {
                    'total': 0,
                    'success': 0,
                    'response_times': []
                }
            
            endpoint_stats[endpoint]['total'] += 1
            if request['success']:
                endpoint_stats[endpoint]['success'] += 1
                endpoint_stats[endpoint]['response_times'].append(request['response_time'])
        
        # Generate report
        print("\n" + "=" * 60)
        print("📊 LOAD TEST RESULTS REPORT")
        print("=" * 60)
        
        print(f"\n🎯 Overall Performance:")
        print(f"   Total Users: {test_results['total_users']}")
        print(f"   Successful Journeys: {test_results['successful_journeys']}")
        print(f"   Success Rate: {test_results['success_rate']:.1f}%")
        print(f"   Total Test Time: {test_results['total_time']:.2f} seconds")
        print(f"   Users per Second: {test_results['total_users'] / test_results['total_time']:.2f}")
        
        if response_times:
            print(f"\n⚡ Response Time Statistics:")
            print(f"   Average: {statistics.mean(response_times):.3f}s")
            print(f"   Median: {statistics.median(response_times):.3f}s")
            print(f"   95th Percentile: {sorted(response_times)[int(len(response_times) * 0.95)]:.3f}s")
            print(f"   99th Percentile: {sorted(response_times)[int(len(response_times) * 0.99)]:.3f}s")
            print(f"   Min: {min(response_times):.3f}s")
            print(f"   Max: {max(response_times):.3f}s")
        
        print(f"\n🔗 Endpoint Performance:")
        for endpoint, stats in endpoint_stats.items():
            success_rate = (stats['success'] / stats['total']) * 100
            avg_response = statistics.mean(stats['response_times']) if stats['response_times'] else 0
            
            status_icon = "✅" if success_rate > 95 else "⚠️" if success_rate > 80 else "❌"
            print(f"   {status_icon} {endpoint}")
            print(f"      Success: {stats['success']}/{stats['total']} ({success_rate:.1f}%)")
            print(f"      Avg Response: {avg_response:.3f}s")
        
        if failed_requests:
            print(f"\n❌ Failed Requests ({len(failed_requests)}):")
            error_counts = {}
            for req in failed_requests[:10]:  # Show first 10 failures
                error = req.get('error', f"HTTP {req['status']}")
                error_counts[error] = error_counts.get(error, 0) + 1
                print(f"   {req['endpoint']}: {error}")
            
            if len(failed_requests) > 10:
                print(f"   ... and {len(failed_requests) - 10} more")
        
        # Performance recommendations
        print(f"\n💡 Performance Recommendations:")
        
        avg_response_time = statistics.mean(response_times) if response_times else 0
        if avg_response_time > 2.0:
            print("   ❌ Average response time > 2s - Consider scaling up")
        elif avg_response_time > 1.0:
            print("   ⚠️  Average response time > 1s - Monitor closely")
        else:
            print("   ✅ Response times are good")
        
        if test_results['success_rate'] < 95:
            print("   ❌ Success rate < 95% - Investigate failures")
        elif test_results['success_rate'] < 99:
            print("   ⚠️  Success rate < 99% - Room for improvement")
        else:
            print("   ✅ Excellent success rate")
        
        # Capacity assessment
        print(f"\n📈 Capacity Assessment:")
        if test_results['success_rate'] > 95 and avg_response_time < 1.0:
            print(f"   ✅ System handled {self.num_users} users well")
            print(f"   💡 Consider testing with {int(self.num_users * 1.5)} users next")
        else:
            print(f"   ⚠️  System struggled with {self.num_users} users")
            print(f"   💡 Current capacity appears to be around {int(self.num_users * 0.8)} users")
        
        # Save detailed results
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        with open(f'load_test_results_{timestamp}.json', 'w') as f:
            json.dump({
                'summary': test_results,
                'endpoint_stats': endpoint_stats,
                'all_requests': all_requests
            }, f, indent=2, default=str)
        
        print(f"\n💾 Detailed results saved to: load_test_results_{timestamp}.json")

async def main():
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python load_test.py <base_url> [num_users]")
        print("Example: python load_test.py http://your-alb-url.com 350")
        return
    
    base_url = sys.argv[1]
    num_users = int(sys.argv[2]) if len(sys.argv) > 2 else 350
    
    tester = LoadTester(base_url, num_users)
    
    try:
        results = await tester.run_concurrent_test()
        tester.analyze_results(results)
    except KeyboardInterrupt:
        print("\n⚠️  Test interrupted by user")
    except Exception as e:
        print(f"\n❌ Test failed: {e}")

if __name__ == "__main__":
    asyncio.run(main())