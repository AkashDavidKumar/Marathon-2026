# Quick Fix: Enable Gzip Compression on All Instances
$region = "ap-southeast-1"

Write-Host "=== ENABLING GZIP COMPRESSION ===" -ForegroundColor Cyan

# Get running instances
$ips = aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text --region $region
$ipList = $ips -split "\s+" | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+$" }

Write-Host "Found $($ipList.Count) instances"

# Create gzip config file
$gzipConfig = @'

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 1000;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/x-javascript;
'@

$gzipConfig | Out-File -FilePath "gzip_config.txt" -Encoding ASCII

foreach ($ip in $ipList) {
    Write-Host "`nConfiguring $ip..."
    
    # Upload and apply
    scp -i debug-marathon-key-v2.pem -o StrictHostKeyChecking=no gzip_config.txt ubuntu@${ip}:/tmp/gzip_config.txt
    ssh -i debug-marathon-key-v2.pem -o StrictHostKeyChecking=no ubuntu@$ip "sudo bash -c 'cat /tmp/gzip_config.txt >> /etc/nginx/conf.d/debug-marathon.conf && nginx -t && systemctl reload nginx'"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ Gzip enabled on $ip" -ForegroundColor Green
    }
    else {
        Write-Host "   ✗ Failed on $ip" -ForegroundColor Red
    }
}

Remove-Item gzip_config.txt -ErrorAction SilentlyContinue

Write-Host "`n=== COMPRESSION ENABLED ===" -ForegroundColor Green
Write-Host "Test the site now - should be 3-5x faster!"
