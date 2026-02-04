# Update Infrastructure Script - V3 (Launch Template + ASG Refresh)
$templateName = "debug-marathon-template"
$asgName = "DebugMarathonASG" # Hardcoded or detected
$region = "ap-southeast-1"

# 1. Detect ASG Name via CloudFormation
Write-Host "Detecting ASG from Stack..."
$stackName = "debug-marathon-stack"
$asgName = aws cloudformation describe-stack-resource --stack-name $stackName --logical-resource-id AutoScalingGroup --region $region --query "StackResourceDetail.PhysicalResourceId" --output text
$asgName = $asgName.Trim()

if (!$asgName) { Write-Error "ASG not found in stack"; exit }
Write-Host "Found ASG: $asgName"

# 2. Get Launch Template ID
Write-Host "Getting Launch Template..."
$ltId = aws ec2 describe-launch-templates --launch-template-names $templateName --region $region --query "LaunchTemplates[0].LaunchTemplateId" --output text
$ltId = $ltId.Trim()
if (!$ltId) { Write-Error "Launch Template not found"; exit }

# 3. Read and Encode User Data
Write-Host "Encoding User Data..."
$userDataContent = [IO.File]::ReadAllText("user_data_optimized.sh")
$userDataBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userDataContent))

# 4. Create New Version
Write-Host "Creating Launch Template Version..."
$ver = aws ec2 create-launch-template-version --launch-template-id $ltId --region $region --launch-template-data "{\""UserData\"":\""$userDataBase64\""}" --query "LaunchTemplateVersion.VersionNumber" --output text
Write-Host "Created Version: $ver"

# 5. Update ASG to use Latest Version (if not already set to $Latest)
# Usually ASG is set to use a specific version or $Latest. Let's force it to ensure it picks up.
# Actually, just starting an instance refresh is usually enough if the LT uses $Latest strategy.
# But let's be explicit and update the ASG config to use version '$Latest' just in case it was pinned.

Write-Host "Updating ASG to use Version $ver..."
aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asgName --region $region --launch-template "LaunchTemplateId=$ltId,Version=$ver"

# 6. Start Instance Refresh (Rolling Replacement)
Write-Host "Starting Instance Refresh (Rolling Update)..."
aws autoscaling start-instance-refresh `
    --auto-scaling-group-name $asgName `
    --region $region `
    --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 180}' `
    --query "InstanceRefreshId"

Write-Host "DONE. Resources are updating zero-downtime."
