# deploy_updates.ps1
$ips = @("54.169.5.230", "13.212.253.90", "13.229.109.204", "47.130.2.117")
$key = "aws-migration/debug-marathon-key-v2.pem"

Write-Host "Updating selected files on $($ips.Count) instances..." -ForegroundColor Cyan

foreach ($ip in $ips) {
    Write-Host "`n>>> Updating $ip ..." -ForegroundColor Yellow
    
    # Upload app.py
    scp -i $key -o StrictHostKeyChecking=no backend/app.py ubuntu@${ip}:/tmp/app.py
    # Upload participant.html
    scp -i $key -o StrictHostKeyChecking=no frontend/participant.html ubuntu@${ip}:/tmp/participant.html
    
    # Move and restart
    ssh -i $key -o StrictHostKeyChecking=no ubuntu@$ip "sudo mv /tmp/app.py /opt/debug-marathon/backend/app.py && sudo mv /tmp/participant.html /opt/debug-marathon/frontend/participant.html && sudo supervisorctl restart debug-marathon && echo 'UPDATE_OK'"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [+] Successfully updated $ip" -ForegroundColor Green
    }
    else {
        Write-Host "   [-] Failed to update $ip" -ForegroundColor Red
    }
}

Write-Host "`nUpdate Complete!" -ForegroundColor Green
