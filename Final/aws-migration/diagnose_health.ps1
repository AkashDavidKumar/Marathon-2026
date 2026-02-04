$tgArn = "arn:aws:elasticloadbalancing:ap-southeast-1:052150906633:targetgroup/debug-marathon-targets/2234f0e8d63d49c0"
Write-Host "Checking Target Health..."
try {
    $json = aws elbv2 describe-target-health --target-group-arn $tgArn --region ap-southeast-1 --query "TargetHealthDescriptions[*]" --output json
    $health = $json | ConvertFrom-Json
}
catch {
    Write-Host "Error parsing JSON: $_"
    exit
}

$unhealthy = $health | Where-Object { $_.TargetHealth.State -ne "healthy" }

if ($unhealthy) {
    Write-Host "Found $($unhealthy.Count) Unhealthy Targets:" -ForegroundColor Red
    
    foreach ($t in $unhealthy) {
        $id = $t.Target.Id
        $state = $t.TargetHealth.State
        $reason = $t.TargetHealth.Reason
        $desc = $t.TargetHealth.Description
        
        Write-Host "[$id] $state - $reason ($desc)"
        
        # Get IP
        $ip = aws ec2 describe-instances --instance-ids $id --query "Reservations[0].Instances[0].PublicIpAddress" --output text
        $ip = $ip.Trim()
        
        if ($ip) {
            Write-Host "   -> Public IP: $ip"
            # Attempt to get logs
            Write-Host "   -> Fetching logs..."
            
            $cmd = "ssh -i debug-marathon-key-v2.pem -o StrictHostKeyChecking=no ubuntu@$ip 'tail -n 20 /var/log/debug-marathon.log; echo ===NGINX===; tail -n 20 /var/log/nginx/error.log; echo ===USERDATA===; tail -n 20 /var/log/user-data.log'"
            Invoke-Expression $cmd
        }
    }
}
else {
    Write-Host "All targets are HEALTHY." -ForegroundColor Green
}
