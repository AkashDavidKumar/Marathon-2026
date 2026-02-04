$key = "debug-marathon-key-v2.pem"
$user = "ubuntu"
$nginxConf = "nginx-optimized.conf"
$supConf = "supervisor-real.conf"

Write-Host "Getting running instances..."
$ips = aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text
$ipList = $ips -split "\s+" | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+$" }

if (!$ipList) { Write-Host "No instances."; exit }

foreach ($ip in $ipList) {
    Write-Host "`n--------------------------------------------------"
    Write-Host "Processing $ip..."
    
    # 1. Upload Configs
    Write-Host "-> Uploading configurations..."
    $scpCmd1 = "scp -i $key -o StrictHostKeyChecking=no $nginxConf ${user}@${ip}:/tmp/nginx-optimized.conf"
    $scpCmd2 = "scp -i $key -o StrictHostKeyChecking=no $supConf ${user}@${ip}:/tmp/supervisor-real.conf"
    
    Invoke-Expression $scpCmd1
    if ($LASTEXITCODE -ne 0) { Write-Host "Upload Nginx failed for $ip" -ForegroundColor Red; continue }
    
    Invoke-Expression $scpCmd2
    if ($LASTEXITCODE -ne 0) { Write-Host "Upload Supervisor failed for $ip" -ForegroundColor Red; continue }
    
    # 2. Apply and Restart (Smart Detection)
    Write-Host "-> Applying logic..."
    
    $remoteScript = @"
    # NGINX LOGIC
    if [ -d '/etc/nginx/sites-available' ]; then
        echo 'Detected Ubuntu Nginx structure'
        sudo mv /tmp/nginx-optimized.conf /etc/nginx/sites-available/debug-marathon
        sudo ln -sf /etc/nginx/sites-available/debug-marathon /etc/nginx/sites-enabled/
        sudo rm -f /etc/nginx/sites-enabled/default
        sudo systemctl restart nginx
    elif [ -d '/etc/nginx/conf.d' ]; then
        echo 'Detected standard/Amazon Linux Nginx structure'
        sudo mv /tmp/nginx-optimized.conf /etc/nginx/conf.d/debug-marathon.conf
        sudo systemctl restart nginx
    fi

    # SUPERVISOR LOGIC
    if [ -d '/etc/supervisor/conf.d' ]; then
        echo 'Detected Ubuntu Supervisor structure'
        sudo mv /tmp/supervisor-real.conf /etc/supervisor/conf.d/debug-marathon.conf
        sudo supervisorctl update
        sudo supervisorctl restart debug-marathon
    elif [ -d '/etc/supervisord.d' ]; then
        echo 'Detected Amazon Linux Supervisor structure'
        sudo mv /tmp/supervisor-real.conf /etc/supervisord.d/debug-marathon.ini
        sudo supervisorctl update
        sudo supervisorctl restart debug-marathon
    fi
    
    echo 'Done.'
"@
    
    # Use base64 to avoid quoting hell
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($remoteScript)
    $b64 = [System.Convert]::ToBase64String($bytes)
    
    $sshCmd = "ssh -i $key -o StrictHostKeyChecking=no ${user}@${ip} ""echo $b64 | base64 -d | bash"""
    Invoke-Expression $sshCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS: $ip updated." -ForegroundColor Green
    }
    else {
        Write-Host "ERROR: Failed to run remote script on $ip" -ForegroundColor Red
    }
}

Write-Host "`n--------------------------------------------------"
Write-Host "Deployment Complete."
