# Application Performance Deep Dive
$region = "ap-southeast-1"

Write-Host "=== DEEP PERFORMANCE ANALYSIS ===" -ForegroundColor Cyan

# 1. Check actual instance IPs
Write-Host "`n1. Getting Running Instance IPs..."
$ips = aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:autoscaling:groupName,Values=debug-marathon-asg" --query "Reservations[*].Instances[*].PublicIpAddress" --output text --region $region
$ipList = $ips -split "\s+" | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+$" }
Write-Host "   Found $($ipList.Count) instances: $($ipList -join ', ')"

# 2. Test application response time directly
Write-Host "`n2. Testing Application Response Time..."
$testUrl = "http://debug-marathon-alb-1798040122.ap-southeast-1.elb.amazonaws.com/api/health"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10
    $sw.Stop()
    Write-Host "   Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   Response Time: $($sw.ElapsedMilliseconds)ms"
    if ($sw.ElapsedMilliseconds -gt 1000) {
        Write-Host "   WARNING: Response time > 1 second!" -ForegroundColor Red
    }
}
catch {
    $sw.Stop()
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Time to failure: $($sw.ElapsedMilliseconds)ms"
}

# 3. Check if instances are actually serving traffic
Write-Host "`n3. Checking Instance Application Status..."
foreach ($ip in $ipList | Select-Object -First 2) {
    Write-Host "   Testing $ip..."
    try {
        $directTest = Invoke-WebRequest -Uri "http://$ip/api/health" -UseBasicParsing -TimeoutSec 5
        Write-Host "      Direct: OK ($($directTest.StatusCode))" -ForegroundColor Green
    }
    catch {
        Write-Host "      Direct: FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 4. Check database connectivity from instance
Write-Host "`n4. Testing Database Connectivity..."
$firstIp = $ipList[0]
if ($firstIp) {
    $dbTest = ssh -i "debug-marathon-key-v2.pem" -o StrictHostKeyChecking=no ubuntu@$firstIp "mysql -u admin -pwCZ52GAXKjZOA55q -h debug-marathon-db.cbs2qwqei97e.ap-southeast-1.rds.amazonaws.com -e 'SELECT 1;' 2>&1"
    if ($dbTest -match "ERROR") {
        Write-Host "   DB Connection: FAILED" -ForegroundColor Red
        Write-Host "   $dbTest"
    }
    else {
        Write-Host "   DB Connection: OK" -ForegroundColor Green
    }
}

Write-Host "`n=== ANALYSIS COMPLETE ===" -ForegroundColor Cyan
