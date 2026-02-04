# Apply Gzip Compression Fix to All Instances
$region = "ap-southeast-1"

Write-Host "=== APPLYING GZIP COMPRESSION FIX ===" -ForegroundColor Cyan

# Get all running instances
$ips = aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text --region $region
$ipList = $ips -split "\s+" | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+$" }

Write-Host "Found $($ipList.Count) instances: $($ipList -join ', ')"

foreach ($ip in $ipList) {
    Write-Host "`n=== Fixing $ip ===" -ForegroundColor Yellow
    
    # Fix nginx.conf - restore default and add gzip
    ssh -i debug-marathon-key-v2.pem -o StrictHostKeyChecking=no ubuntu@$ip @"
sudo apt-get install --reinstall -y nginx-core 2>/dev/null
sudo systemctl stop nginx
sudo rm -f /etc/nginx/conf.d/debug-marathon.conf
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
sudo sed -i '/gzip on;/d' /etc/nginx/nginx.conf
sudo sed -i '/gzip_/d' /etc/nginx/nginx.conf
sudo sed -i '/http {/a\    # Gzip Settings\n    gzip on;\n    gzip_vary on;\n    gzip_proxied any;\n    gzip_comp_level 6;\n    gzip_min_length 1000;\n    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/x-javascript text/html;' /etc/nginx/nginx.conf
sudo nginx -t && sudo systemctl start nginx
"@
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ Gzip enabled on $ip" -ForegroundColor Green
    }
    else {
        Write-Host "   ✗ Failed on $ip" -ForegroundColor Red
    }
}

Write-Host "`n=== TESTING COMPRESSION ===" -ForegroundColor Cyan
$albUrl = "http://debug-marathon-alb-1798040122.ap-southeast-1.elb.amazonaws.com"
Write-Host "Testing: $albUrl"
curl -I -H "Accept-Encoding: gzip" $albUrl | Select-String "Content-Encoding"

Write-Host "`n=== COMPLETE ===" -ForegroundColor Green
Write-Host "Gzip compression should now be enabled on all instances!"
Write-Host "Expected improvement: 60-80% reduction in page load time"
