# Optimize Infrastructure Performance (ASG & ALB)
$region = "ap-southeast-1"
$stackName = "debug-marathon-stack"

Write-Host "Fetching Resources..."
# 1. Resolve Names
$asgName = aws cloudformation describe-stack-resource --stack-name $stackName --logical-resource-id AutoScalingGroup --region $region --query "StackResourceDetail.PhysicalResourceId" --output text
$asgName = $asgName.Trim()

$albArn = aws elbv2 describe-load-balancers --region $region --query "LoadBalancers[?contains(LoadBalancerName, 'debug-marathon')].LoadBalancerArn | [0]" --output text
$albArn = $albArn.Trim()

Write-Host "ASG: $asgName"
Write-Host "ALB: $albArn"

# 2. Optimize Auto Scaling (Aggressive Scaling)
Write-Host "Optimizing Auto Scaling Policy..."
# Enable Detailed Monitoring (1-min metrics) on ASG instances (Requires Launch Template update usually, but we can try ASG level)
# Actually, for existing instances, we can't easily change monitoring without replacement. 
# But we can update the policy to be more sensitive.
# Target CPU: 40% (instead of default 50/60) to scale out EARLIER.
# Scale In Cooldown: 60s (scale out fast, scale in slow? no, we want scale out fast)

$policyConf = @"
{
    "TargetValue": 40.0,
    "PredefinedMetricSpecification": {
        "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "DisableScaleIn": false
}
"@
# Save to file to avoid CLI parsing hell
$policyConf | Out-File policy.json -Encoding ASCII

aws autoscaling put-scaling-policy `
    --auto-scaling-group-name $asgName `
    --policy-name "TargetTracking-CPU-40" `
    --policy-type TargetTrackingScaling `
    --target-tracking-configuration file://policy.json `
    --region $region

if ($LASTEXITCODE -eq 0) { Write-Host "ASG Policy Updated: CPU Target 40%" -ForegroundColor Green }
else { Write-Host "ASG Policy Update Failed" -ForegroundColor Red }

# 3. Optimize ALB Attributes
Write-Host "Optimizing ALB Attributes..."
# Idle Timeout: 60s (Standard)
# Drop Invalid Headers: true (Security/Perf)
# HTTP2: true (Performance)

aws elbv2 modify-load-balancer-attributes `
    --load-balancer-arn $albArn `
    --attributes Key=idle_timeout.timeout_seconds, Value=60 Key=routing.http2.enabled, Value=true Key=routing.http.drop_invalid_header_fields.enabled, Value=true `
    --region $region

if ($LASTEXITCODE -eq 0) { Write-Host "ALB Attributes Optimized" -ForegroundColor Green }

# 4. Verify RDS (T3 Unlimited?)
# We cannot easily change T3 Unlimited via CLI without restart/modification. 
# But we can verify storage autoscaling - usually configured in setup.

Write-Host "Performance Tuning Complete."
