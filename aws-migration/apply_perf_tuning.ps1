$instances = @("54.169.5.230", "13.212.253.90", "13.229.109.204", "47.130.2.117")
$key = "d:\marathon\debug-marathon-key-v2.pem"

foreach ($ip in $instances) {
    Write-Host "--- Optimizing Instance: $ip ---"
    
    # 1. Update Supervisor config to include more workers and optimized settings
    $supervisorConfig = @"
[program:debug-marathon]
directory=/opt/debug-marathon/backend
command=/opt/debug-marathon/venv/bin/gunicorn --workers 4 --timeout 120 --bind 0.0.0.0:5000 wsgi:app
user=ubuntu
autostart=true
autorestart=true
stderr_logfile=/var/log/debug-marathon.err.log
stdout_logfile=/var/log/debug-marathon.out.log
environment=PATH="/opt/debug-marathon/venv/bin"
"@
    
    # Upload and apply supervisor config
    $supervisorConfig | Out-File -FilePath "temp_supervisor.conf" -Encoding ascii
    scp -i $key -o StrictHostKeyChecking=no temp_supervisor.conf ubuntu@$($ip):/tmp/debug-marathon.conf
    ssh -i $key -o StrictHostKeyChecking=no ubuntu@$ip "sudo mv /tmp/debug-marathon.conf /etc/supervisor/conf.d/debug-marathon.conf"
    
    # 2. Update Nginx with aggressive Gzip and buffers
    $nginxConfig = @"
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
gzip_proxied any;
gzip_vary on;
gzip_comp_level 6;
gzip_buffers 16 8k;
client_max_body_size 10M;
keepalive_timeout 65;
proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;
"@
    $nginxConfig | Out-File -FilePath "temp_nginx.conf" -Encoding ascii
    scp -i $key -o StrictHostKeyChecking=no temp_nginx.conf ubuntu@$($ip):/tmp/optimization.conf
    ssh -i $key -o StrictHostKeyChecking=no ubuntu@$ip "sudo mv /tmp/optimization.conf /etc/nginx/conf.d/optimization.conf"
    
    # 3. Apply changes
    ssh -i $key -o StrictHostKeyChecking=no ubuntu@$ip "sudo supervisorctl reread; sudo supervisorctl update; sudo supervisorctl restart debug-marathon; sudo systemctl reload nginx"
    
    Write-Host "Successfully optimized $ip"
}

Remove-Item "temp_supervisor.conf", "temp_nginx.conf"
