# Emergency Recovery - Launch Fresh Instances
$region = "ap-southeast-1"

Write-Host "=== EMERGENCY INSTANCE RECOVERY ===" -ForegroundColor Red

# 1. Check current state
Write-Host "`n1. Checking current instances..."
$running = aws ec2 describe-instances --filters "Name=instance-state-name,Values=running,pending" --query "Reservations[*].Instances[*].InstanceId" --output text --region $region
Write-Host "   Running/Pending: $running"

# 2. Force ASG to stabilize
Write-Host "`n2. Stabilizing Auto Scaling Group..."
aws autoscaling suspend-processes --auto-scaling-group-name debug-marathon-asg --scaling-processes HealthCheck --region $region
Write-Host "   Suspended health check terminations"

# 3. Set safe capacity
Write-Host "`n3. Setting safe desired capacity to 4..."
aws autoscaling set-desired-capacity --auto-scaling-group-name debug-marathon-asg --desired-capacity 4 --region $region

# 4. Wait for instances
Write-Host "`n4. Waiting for instances to launch (60 seconds)..."
Start-Sleep -Seconds 60

# 5. Check status
$newRunning = aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,PublicIpAddress]" --output text --region $region
Write-Host "`n5. Current Running Instances:"
Write-Host $newRunning

# 6. Resume processes
Write-Host "`n6. Resuming ASG processes..."
aws autoscaling resume-processes --auto-scaling-group-name debug-marathon-asg --region $region

Write-Host "`n=== RECOVERY COMPLETE ===" -ForegroundColor Green
Write-Host "Check site: http://debug-marathon-alb-1798040122.ap-southeast-1.elb.amazonaws.com"
