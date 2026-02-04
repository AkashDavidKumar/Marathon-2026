# Fix Stickiness for Socket.IO
$tgArn = "arn:aws:elasticloadbalancing:ap-southeast-1:052150906633:targetgroup/debug-marathon-targets/2234f0e8d63d49c0"

Write-Host "Checking Target Group Attributes..."
$attrs = aws elbv2 describe-target-group-attributes --target-group-arn $tgArn --query "Attributes" --output json | ConvertFrom-Json

$stickiness = $attrs | Where-Object { $_.Key -eq "stickiness.enabled" }
$type = $attrs | Where-Object { $_.Key -eq "stickiness.type" }
$dereg = $attrs | Where-Object { $_.Key -eq "deregistration_delay.timeout_seconds" }

Write-Host "Current State:"
Write-Host "   Stickiness: $($stickiness.Value)"
Write-Host "   Type:       $($type.Value)"
Write-Host "   Draining:   $($dereg.Value)"

# We MUST enable stickiness for Socket.IO multi-server setup
if ($stickiness.Value -ne "true") {
    Write-Host "-> Enabling Stickiness (Crucial for Socket.IO)..."
    aws elbv2 modify-target-group-attributes `
        --target-group-arn $tgArn `
        --attributes Key=stickiness.enabled, Value=true Key=stickiness.type, Value=lb_cookie Key=stickiness.lb_cookie.duration_seconds, Value=86400
    Write-Host "   FIXED." -ForegroundColor Green
}
else {
    Write-Host "   Stickiness is already enabled." -ForegroundColor Green
}

# Optimize Draining (Speed up updates)
if ($dereg.Value -gt 60) {
    Write-Host "-> Optimizing Deregistration Delay to 60s..."
    aws elbv2 modify-target-group-attributes `
        --target-group-arn $tgArn `
        --attributes Key=deregistration_delay.timeout_seconds, Value=60
    Write-Host "   FIXED." -ForegroundColor Green
}
