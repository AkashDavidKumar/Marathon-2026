# Master Performance Tuning Script
$tgArn = "arn:aws:elasticloadbalancing:ap-southeast-1:052150906633:targetgroup/debug-marathon-targets/2234f0e8d63d49c0"
$region = "ap-southeast-1"

Write-Host "1. Optimizing Target Group (Stickiness & Draining)..."
# Stickiness is MANDATORY for Socket.IO with multiple servers
# Deregistration Delay = 30s for faster deploys
aws elbv2 modify-target-group-attributes `
    --target-group-arn $tgArn `
    --attributes Key=stickiness.enabled, Value=true Key=stickiness.lb_cookie.duration_seconds, Value=86400 Key=deregistration_delay.timeout_seconds, Value=30 `
    --region $region

if ($LASTEXITCODE -eq 0) { Write-Host "   -> Stickiness Enabled (1 day cookie), Draining set to 30s." -ForegroundColor Green }
else { Write-Host "   -> Failed to set attributes." -ForegroundColor Red }

Write-Host "2. Optimizing Health Checks..."
# Faster reaction to failures
aws elbv2 modify-target-group `
    --target-group-arn $tgArn `
    --health-check-interval-seconds 20 `
    --health-check-timeout-seconds 10 `
    --healthy-threshold-count 2 `
    --unhealthy-threshold-count 3 `
    --region $region
    
if ($LASTEXITCODE -eq 0) { Write-Host "   -> Health Checks Optimized (20s interval, 2 successes)." -ForegroundColor Green }


Write-Host "3. Enabling RDS Performance Insights (Free Tier)..."
aws rds modify-db-instance `
    --db-instance-identifier debug-marathon-db `
    --enable-performance-insights `
    --performance-insights-retention-period 7 `
    --apply-immediately `
    --region $region

if ($LASTEXITCODE -eq 0) { Write-Host "   -> RDS Performance Insights Enabled." -ForegroundColor Green }

Write-Host "4. Verifying Instance Scalability..."
# Ensure ASG has room to grow
aws autoscaling update-auto-scaling-group `
    --auto-scaling-group-name debug-marathon-asg `
    --max-size 10 `
    --default-cooldown 60 `
    --region $region

if ($LASTEXITCODE -eq 0) { Write-Host "   -> ASG Max Limit Increased to 10." -ForegroundColor Green }

Write-Host "ALL PERFORMANCE TUNING COMPLETE."
