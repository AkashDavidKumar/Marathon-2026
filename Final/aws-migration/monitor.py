#!/usr/bin/env python3
"""
Simple monitoring dashboard for Debug Marathon Application
Monitors AWS resources and application health
"""

import boto3
import json
import time
from datetime import datetime, timedelta
import requests

class DebugMarathonMonitor:
    def __init__(self, stack_name, region='ap-southeast-1'):
        self.stack_name = stack_name
        self.region = region
        
        # AWS clients
        self.cloudformation = boto3.client('cloudformation', region_name=region)
        self.ec2 = boto3.client('ec2', region_name=region)
        self.rds = boto3.client('rds', region_name=region)
        self.elbv2 = boto3.client('elbv2', region_name=region)
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        
        # Stack resources
        self.resources = {}
        self.load_balancer_url = None
        
    def get_stack_resources(self):
        """Get all resources from CloudFormation stack"""
        try:
            response = self.cloudformation.describe_stacks(StackName=self.stack_name)
            
            # Get outputs
            outputs = response['Stacks'][0]['Outputs']
            for output in outputs:
                if output['OutputKey'] == 'LoadBalancerURL':
                    self.load_balancer_url = output['OutputValue']
            
            # Get resources
            resources_response = self.cloudformation.describe_stack_resources(StackName=self.stack_name)
            for resource in resources_response['StackResources']:
                self.resources[resource['LogicalResourceId']] = resource['PhysicalResourceId']
            
            return True
            
        except Exception as e:
            print(f"❌ Error getting stack resources: {e}")
            return False
    
    def check_application_health(self):
        """Check application health endpoint"""
        if not self.load_balancer_url:
            return {'status': 'unknown', 'error': 'No load balancer URL'}
        
        try:
            health_url = f"{self.load_balancer_url}/api/health"
            response = requests.get(health_url, timeout=10)
            
            if response.status_code == 200:
                return {
                    'status': 'healthy',
                    'response_time': response.elapsed.total_seconds(),
                    'data': response.json() if response.headers.get('content-type', '').startswith('application/json') else None
                }
            else:
                return {
                    'status': 'unhealthy',
                    'status_code': response.status_code,
                    'response_time': response.elapsed.total_seconds()
                }
                
        except Exception as e:
            return {'status': 'error', 'error': str(e)}
    
    def get_ec2_instances_status(self):
        """Get status of EC2 instances"""
        try:
            # Get Auto Scaling Group instances
            asg_name = self.resources.get('AutoScalingGroup')
            if not asg_name:
                return []
            
            autoscaling = boto3.client('autoscaling', region_name=self.region)
            response = autoscaling.describe_auto_scaling_groups(
                AutoScalingGroupNames=[asg_name]
            )
            
            instances = []
            if response['AutoScalingGroups']:
                asg = response['AutoScalingGroups'][0]
                instance_ids = [i['InstanceId'] for i in asg['Instances']]
                
                if instance_ids:
                    ec2_response = self.ec2.describe_instances(InstanceIds=instance_ids)
                    
                    for reservation in ec2_response['Reservations']:
                        for instance in reservation['Instances']:
                            instances.append({
                                'instance_id': instance['InstanceId'],
                                'state': instance['State']['Name'],
                                'public_ip': instance.get('PublicIpAddress', 'N/A'),
                                'private_ip': instance.get('PrivateIpAddress', 'N/A'),
                                'instance_type': instance['InstanceType'],
                                'launch_time': instance['LaunchTime'].isoformat()
                            })
            
            return instances
            
        except Exception as e:
            print(f"❌ Error getting EC2 status: {e}")
            return []
    
    def get_rds_status(self):
        """Get RDS database status"""
        try:
            db_instance_id = self.resources.get('Database')
            if not db_instance_id:
                return {'status': 'not_found'}
            
            response = self.rds.describe_db_instances(DBInstanceIdentifier=db_instance_id)
            
            if response['DBInstances']:
                db = response['DBInstances'][0]
                return {
                    'status': db['DBInstanceStatus'],
                    'engine': db['Engine'],
                    'version': db['EngineVersion'],
                    'instance_class': db['DBInstanceClass'],
                    'storage': db['AllocatedStorage'],
                    'endpoint': db.get('Endpoint', {}).get('Address', 'N/A'),
                    'port': db.get('Endpoint', {}).get('Port', 'N/A')
                }
            
            return {'status': 'not_found'}
            
        except Exception as e:
            print(f"❌ Error getting RDS status: {e}")
            return {'status': 'error', 'error': str(e)}
    
    def get_load_balancer_status(self):
        """Get Load Balancer status"""
        try:
            lb_arn = self.resources.get('LoadBalancer')
            if not lb_arn:
                return {'status': 'not_found'}
            
            # Get load balancer details
            lb_response = self.elbv2.describe_load_balancers(LoadBalancerArns=[lb_arn])
            
            if lb_response['LoadBalancers']:
                lb = lb_response['LoadBalancers'][0]
                
                # Get target group health
                tg_arn = self.resources.get('TargetGroup')
                healthy_targets = 0
                total_targets = 0
                
                if tg_arn:
                    health_response = self.elbv2.describe_target_health(TargetGroupArn=tg_arn)
                    total_targets = len(health_response['TargetHealthDescriptions'])
                    healthy_targets = sum(1 for t in health_response['TargetHealthDescriptions'] 
                                        if t['TargetHealth']['State'] == 'healthy')
                
                return {
                    'status': lb['State']['Code'],
                    'dns_name': lb['DNSName'],
                    'scheme': lb['Scheme'],
                    'type': lb['Type'],
                    'healthy_targets': healthy_targets,
                    'total_targets': total_targets
                }
            
            return {'status': 'not_found'}
            
        except Exception as e:
            print(f"❌ Error getting Load Balancer status: {e}")
            return {'status': 'error', 'error': str(e)}
    
    def get_cloudwatch_metrics(self):
        """Get key CloudWatch metrics"""
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=10)
        
        metrics = {}
        
        try:
            # EC2 CPU utilization
            asg_name = self.resources.get('AutoScalingGroup', '').split('/')[-1]
            if asg_name:
                response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/EC2',
                    MetricName='CPUUtilization',
                    Dimensions=[{'Name': 'AutoScalingGroupName', 'Value': asg_name}],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Average']
                )
                
                if response['Datapoints']:
                    latest_cpu = sorted(response['Datapoints'], key=lambda x: x['Timestamp'])[-1]
                    metrics['avg_cpu_utilization'] = round(latest_cpu['Average'], 2)
                else:
                    metrics['avg_cpu_utilization'] = 0
            
            # RDS connections
            db_instance_id = self.resources.get('Database')
            if db_instance_id:
                response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/RDS',
                    MetricName='DatabaseConnections',
                    Dimensions=[{'Name': 'DBInstanceIdentifier', 'Value': db_instance_id}],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Average']
                )
                
                if response['Datapoints']:
                    latest_conn = sorted(response['Datapoints'], key=lambda x: x['Timestamp'])[-1]
                    metrics['db_connections'] = round(latest_conn['Average'], 0)
                else:
                    metrics['db_connections'] = 0
            
            # Load Balancer request count
            lb_name = self.resources.get('LoadBalancer', '').split('/')[-3:]
            if len(lb_name) >= 3:
                lb_full_name = '/'.join(lb_name)
                response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/ApplicationELB',
                    MetricName='RequestCount',
                    Dimensions=[{'Name': 'LoadBalancer', 'Value': lb_full_name}],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Sum']
                )
                
                if response['Datapoints']:
                    total_requests = sum(dp['Sum'] for dp in response['Datapoints'])
                    metrics['requests_per_minute'] = round(total_requests / 10, 2)  # 10 minutes average
                else:
                    metrics['requests_per_minute'] = 0
            
            return metrics
            
        except Exception as e:
            print(f"❌ Error getting CloudWatch metrics: {e}")
            return {}
    
    def display_dashboard(self):
        """Display monitoring dashboard"""
        print("\n" + "=" * 80)
        print("📊 DEBUG MARATHON - MONITORING DASHBOARD")
        print("=" * 80)
        print(f"Stack: {self.stack_name} | Region: {self.region} | Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        # Application Health
        health = self.check_application_health()
        health_icon = "✅" if health['status'] == 'healthy' else "❌"
        print(f"🏥 APPLICATION HEALTH: {health_icon} {health['status'].upper()}")
        
        if health['status'] == 'healthy':
            print(f"   URL: {self.load_balancer_url}")
            print(f"   Response Time: {health.get('response_time', 0):.3f}s")
        elif 'error' in health:
            print(f"   Error: {health['error']}")
        print()
        
        # EC2 Instances
        instances = self.get_ec2_instances_status()
        print(f"🖥️  EC2 INSTANCES: {len(instances)} running")
        
        for i, instance in enumerate(instances, 1):
            state_icon = "✅" if instance['state'] == 'running' else "❌"
            print(f"   {state_icon} Instance {i}: {instance['instance_id']}")
            print(f"      State: {instance['state']} | Type: {instance['instance_type']}")
            print(f"      Public IP: {instance['public_ip']} | Private IP: {instance['private_ip']}")
        print()
        
        # RDS Database
        rds = self.get_rds_status()
        rds_icon = "✅" if rds['status'] == 'available' else "❌"
        print(f"🗄️  DATABASE: {rds_icon} {rds['status'].upper()}")
        
        if rds['status'] == 'available':
            print(f"   Engine: {rds['engine']} {rds['version']}")
            print(f"   Instance: {rds['instance_class']} | Storage: {rds['storage']}GB")
            print(f"   Endpoint: {rds['endpoint']}:{rds['port']}")
        print()
        
        # Load Balancer
        lb = self.get_load_balancer_status()
        lb_icon = "✅" if lb['status'] == 'active' else "❌"
        print(f"⚖️  LOAD BALANCER: {lb_icon} {lb['status'].upper()}")
        
        if lb['status'] == 'active':
            print(f"   DNS: {lb['dns_name']}")
            print(f"   Healthy Targets: {lb['healthy_targets']}/{lb['total_targets']}")
        print()
        
        # CloudWatch Metrics
        metrics = self.get_cloudwatch_metrics()
        print(f"📈 PERFORMANCE METRICS (Last 10 minutes):")
        print(f"   Average CPU: {metrics.get('avg_cpu_utilization', 'N/A')}%")
        print(f"   DB Connections: {metrics.get('db_connections', 'N/A')}")
        print(f"   Requests/Min: {metrics.get('requests_per_minute', 'N/A')}")
        print()
        
        # Health Summary
        health_score = 0
        total_checks = 4
        
        if health['status'] == 'healthy':
            health_score += 1
        if any(i['state'] == 'running' for i in instances):
            health_score += 1
        if rds['status'] == 'available':
            health_score += 1
        if lb['status'] == 'active':
            health_score += 1
        
        health_percentage = (health_score / total_checks) * 100
        health_status = "🟢 HEALTHY" if health_percentage >= 75 else "🟡 WARNING" if health_percentage >= 50 else "🔴 CRITICAL"
        
        print(f"🎯 SYSTEM HEALTH: {health_status} ({health_percentage:.0f}%)")
        print("=" * 80)

def main():
    import sys
    import argparse
    
    parser = argparse.ArgumentParser(description='Debug Marathon Monitoring Dashboard')
    parser.add_argument('--stack-name', default='debug-marathon-stack', 
                       help='CloudFormation stack name')
    parser.add_argument('--region', default='ap-southeast-1', 
                       help='AWS region')
    parser.add_argument('--interval', type=int, default=30, 
                       help='Refresh interval in seconds (0 for single run)')
    
    args = parser.parse_args()
    
    monitor = DebugMarathonMonitor(args.stack_name, args.region)
    
    # Load stack resources
    if not monitor.get_stack_resources():
        print("❌ Failed to load stack resources. Check stack name and region.")
        return
    
    try:
        if args.interval > 0:
            # Continuous monitoring
            while True:
                monitor.display_dashboard()
                print(f"\n⏱️  Refreshing in {args.interval} seconds... (Ctrl+C to stop)")
                time.sleep(args.interval)
        else:
            # Single run
            monitor.display_dashboard()
            
    except KeyboardInterrupt:
        print("\n👋 Monitoring stopped by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")

if __name__ == "__main__":
    main()