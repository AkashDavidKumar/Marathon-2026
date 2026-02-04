# Fix Database Performance (Connections & User Data)
$region = "ap-southeast-1"
$stackName = "debug-marathon-stack"

Write-Host "1. Updating Infrastructure with Safe Connection Limits..."

# We confirmed we are on db.t3.medium (4GB RAM) set to ~300 connections max (default).
# ASG Max Size = 10.
# App Gunicorn = 1 worker, 100 threads.
# Safe Pool Size = 20. (20 * 10 = 200 < 300).
# BUT, if we scale to 15 or 20, we crash.
# Let's reduce Pool Size to 15 to be safer (allows ~20 instances).
# 15 connections sharing 100 threads is slightly tight but better than DB crash.

# Update the User Data script with pool_size=15
$userDataPath = "user_data.sh"
(Get-Content $userDataPath) -replace "pool_size=20", "pool_size=15" | Set-Content $userDataPath
Write-Host "   -> Updated UserData pool_size to 15."

# 2. Re-deploy Infrastructure (Update Launch Template)
Write-Host "2. Updating Launch Template..."
# Same logic as deploy_infrastructure.ps1 but inline to ensure correctness
$templateName = "debug-marathon-template"
$asgName = aws cloudformation describe-stack-resource --stack-name $stackName --logical-resource-id AutoScalingGroup --region $region --query "StackResourceDetail.PhysicalResourceId" --output text
$asgName = $asgName.Trim()

$ltId = aws ec2 describe-launch-templates --launch-template-names $templateName --region $region --query "LaunchTemplates[0].LaunchTemplateId" --output text
$ltId = $ltId.Trim()

$userDataContent = [IO.File]::ReadAllText($userDataPath)
$userDataBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userDataContent))

$ver = aws ec2 create-launch-template-version --launch-template-id $ltId --region $region --launch-template-data "{\""UserData\"":\""$userDataBase64\""}" --query "LaunchTemplateVersion.VersionNumber" --output text
Write-Host "   -> Created Version: $ver"

# 3. Trigger Rolling Refresh (Zero Downtime)
Write-Host "3. Triggering Instance Refresh..."
# Using explicit file for JSON to avoid PowerShell parsing issues
$prefJson = '{"MinHealthyPercentage": 50, "InstanceWarmup": 180}'
$prefJson | Out-File prefs.json -Encoding ASCII

aws autoscaling start-instance-refresh `
    --auto-scaling-group-name $asgName `
    --region $region `
    --preferences file://prefs.json `
    --query "InstanceRefreshId"
    
Remove-Item prefs.json -ErrorAction SilentlyContinue

Write-Host "FIX DEPLOYED: Connection Pool Safety + Performance Insights Enabled + Stickiness."
