# Create CloudWatch Dashboard
$region = "ap-southeast-1"
$dashboardName = "debug-marathon-monitor"

Write-Host "Discovering Resources..."

# 1. Get ALB
$albArn = aws elbv2 describe-load-balancers --region $region --query "LoadBalancers[?contains(LoadBalancerName, 'debug-marathon')].LoadBalancerArn | [0]" --output text
$albArn = $albArn.Trim()
if (!$albArn) { Write-Error "ALB not found"; exit }
# Extract explicit name for metrics (app/name/id)
$albMetricName = $albArn -replace "arn:aws:elasticloadbalancing:.*:loadbalancer/", ""

# 2. Get Target Group
$tgArn = aws elbv2 describe-target-groups --region $region --query "TargetGroups[?contains(TargetGroupName, 'debug-marathon')].TargetGroupArn | [0]" --output text
$tgArn = $tgArn.Trim()
# Extract explicit name (targetgroup/name/id)
$tgMetricName = $tgArn -replace "arn:aws:elasticloadbalancing:.*:targetgroup/", "targetgroup/"

# 3. Get ASG
$asgForMetric = "debug-marathon-asg" # Default
# Verify
$finalAsg = aws autoscaling describe-auto-scaling-groups --region $region --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'debug-marathon')].AutoScalingGroupName | [0]" --output text
if ($finalAsg) { $asgForMetric = $finalAsg.Trim() }

# 4. RDS
$rdsId = "debug-marathon-db"


Write-Host "Resources Found:"
Write-Host "ALB: $albMetricName"
Write-Host "TG:  $tgMetricName"
Write-Host "ASG: $asgForMetric"
Write-Host "RDS: $rdsId"

# Define Dashboard Widget Structure directly in PowerShell (JSON String)
$dashboardBody = @"
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "$albMetricName", { "stat": "Sum", "period": 60 } ],
                    [ ".", "HTTPCode_Target_4XX_Count", ".", ".", { "stat": "Sum", "period": 60 } ],
                    [ ".", "HTTPCode_Target_5XX_Count", ".", ".", { "stat": "Sum", "period": 60, "color": "#d62728" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$region",
                "title": "Traffic & Errors (ALB)"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "$albMetricName", "TargetGroup", "$tgMetricName", { "stat": "Average", "period": 60 } ],
                    [ "...", { "stat": "p95", "period": 60, "label": "p95" } ]
                ],
                "view": "timeSeries",
                "region": "$region",
                "title": "Response Time (Latency)"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "$asgForMetric", { "period": 60 } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$region",
                "title": "EC2 CPU Utilization (ASG)"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "$rdsId", { "period": 60 } ],
                    [ ".", "DatabaseConnections", ".", ".", { "period": 60, "yAxis": "right" } ]
                ],
                "view": "timeSeries",
                "region": "$region",
                "title": "Database CPU & Connections"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 12,
            "width": 24,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", "$albMetricName", { "period": 60 } ],
                    [ ".", "NewConnectionCount", ".", ".", { "period": 60 } ]
                ],
                "view": "timeSeries",
                "region": "$region",
                "title": "Connection Stability"
            }
        }
    ]
}
"@

# Save to file to avoid CLI parsing issues
$jsonPath = "dashboard.json"
$dashboardBody | Out-File -FilePath $jsonPath -Encoding ASCII
Write-Host "JSON saved to $jsonPath"

# Upload Dashboard
Write-Host "Creating Dashboard '$dashboardName'..."
# Note: file:// prefix is required for file input
aws cloudwatch put-dashboard --dashboard-name $dashboardName --dashboard-body "file://$jsonPath"

if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "View here: https://ap-southeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-southeast-1#dashboards:name=$dashboardName"
}
else {
    Write-Host "FAILED to upload dashboard." -ForegroundColor Red
}
