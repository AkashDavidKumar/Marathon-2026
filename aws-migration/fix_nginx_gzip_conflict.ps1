$instances = @("54.169.5.230", "13.212.253.90", "13.229.109.204", "47.130.2.117")
$key = "d:\marathon\debug-marathon-key-v2.pem"

foreach ($ip in $instances) {
    Write-Host "Reverting and Fixing Nginx on $ip..."
    
    # 1. Remove the broken optimization file causing "duplicate gzip" errors
    ssh -i $key -o StrictHostKeyChecking=no ubuntu@$ip "sudo rm -f /etc/nginx/conf.d/optimization.conf"
    
    # 2. Verify Config
    $test = ssh -i $key -o StrictHostKeyChecking=no ubuntu@$ip "sudo nginx -t" 2>&1
    
    if ($test -match "successful") {
        # 3. Restart Nginx if config is valid
        ssh -i $key -o StrictHostKeyChecking=no ubuntu@$ip "sudo systemctl restart nginx"
        Write-Host "Success: Nginx recovered on $ip"
    } else {
        Write-Host "Error: Nginx config invalid on $ip"
        Write-Host $test
    }
}
