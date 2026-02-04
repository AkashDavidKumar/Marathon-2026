# AWS Migration Guide for Debug Marathon Application
# Optimized for 350+ Concurrent Users at Minimal Cost

## Overview
This migration solution uses AWS Free Tier and cost-effective services to handle 350+ concurrent users while keeping costs under $50/month.

## Cost Breakdown (Monthly Estimates)
- **EC2 Instances**: 2x t3.small (Auto Scaling 2-6) = $30-90
- **RDS MySQL**: db.t3.micro (20GB) = $15
- **Application Load Balancer**: $16
- **Data Transfer**: ~$5
- **S3 Storage**: <$1
- **Total**: $67-117/month (with Free Tier benefits: $20-50/month)

## Architecture Components

### 1. Infrastructure (CloudFormation)
- **VPC**: Custom VPC with public/private subnets
- **EC2**: Auto Scaling Group (2-6 t3.small instances)
- **RDS**: MySQL 8.0 (db.t3.micro, 20GB storage)
- **ALB**: Application Load Balancer for high availability
- **S3**: Static asset hosting
- **Auto Scaling**: CPU-based scaling (target 70%)

### 2. Application Stack
- **Web Server**: Nginx (reverse proxy + static files)
- **App Server**: Gunicorn with 4 workers per instance
- **Database**: RDS MySQL with connection pooling
- **Monitoring**: CloudWatch logs and metrics
- **Process Management**: Supervisor

## Performance Optimizations for 350+ Users

### 1. Connection Pooling
- MySQL connection pool: 30 connections per instance
- Total capacity: 180-360 connections (6 instances max)

### 2. Load Balancing
- Application Load Balancer distributes traffic
- Health checks ensure only healthy instances serve traffic
- Sticky sessions for WebSocket connections

### 3. Auto Scaling
- Scales from 2 to 6 instances based on CPU usage
- Target CPU utilization: 70%
- Scale-out time: ~2-3 minutes

### 4. Caching Strategy
- Static assets served directly by Nginx
- Browser caching headers (1 year for static assets)
- Gzip compression enabled

## Migration Steps

### Prerequisites
1. **AWS CLI installed and configured**
   ```bash
   aws configure
   # Enter your Access Key, Secret Key, Region, and Output format
   ```

2. **EC2 Key Pair created**
   - Go to EC2 Console → Key Pairs → Create Key Pair
   - Download the .pem file for SSH access

3. **MySQL installed locally** (for database export)
   - Ensure you can run `mysqldump` command

4. **Get Latest AMI IDs** (Important!)
   ```bash
   # Linux/Mac
   chmod +x get-latest-amis.sh
   ./get-latest-amis.sh
   
   # Windows
   get-latest-amis.bat
   ```
   Copy the output and update the AMI mappings in `cloudformation-template.yaml`

### Step 1: Update AMI Mappings
Before running the migration, you MUST update the AMI mappings in the CloudFormation template:

1. Run the AMI script to get latest IDs
2. Replace the placeholder AMI IDs in `cloudformation-template.yaml`
3. Verify the AMI IDs are valid for your target regions

### Step 2: Run Migration Script
**Windows:**
```cmd
migrate.bat
```

**Linux/Mac:**
```bash
./migrate.sh
```

### Step 3: Manual Steps
1. **Update Database Config**: The script creates `db_config_production.ini`
2. **Upload Application Code**: 
   ```bash
   # Zip your application
   zip -r debug-marathon.zip ../backend ../frontend
   
   # Upload to EC2 instances (replace with your instance IPs)
   scp -i your-key.pem debug-marathon.zip ec2-user@INSTANCE-IP:/tmp/
   ```

3. **Deploy on Each Instance**:
   ```bash
   ssh -i your-key.pem ec2-user@INSTANCE-IP
   cd /tmp
   unzip debug-marathon.zip
   chmod +x deploy_application.sh
   ./deploy_application.sh
   ```

## Configuration Files

### Database Configuration
```ini
[mysql]
host = your-rds-endpoint
port = 3306
database = debug_marathon_v3
user = admin
password = your-password
charset = utf8mb4
collation = utf8mb4_unicode_ci
pool_size = 30
pool_name = debug_marathon_pool
```

### Nginx Configuration
- Load balancing across 4 Gunicorn workers
- WebSocket support for Socket.IO
- Static file serving
- Security headers
- Gzip compression

### Supervisor Configuration
- 4 Gunicorn processes per instance
- Automatic restart on failure
- Log management
- Process monitoring

## Monitoring and Maintenance

### CloudWatch Metrics
- EC2 CPU, Memory, Disk usage
- Application logs
- Nginx access/error logs
- RDS performance metrics

### Health Checks
- ALB health checks on `/api/health`
- Supervisor process monitoring
- Automated instance replacement on failure

### Log Files
- Application logs: `/var/log/debug-marathon-*.log`
- Nginx logs: `/var/log/nginx/`
- System logs: CloudWatch Logs

## Scaling Considerations

### Current Capacity
- **2 instances**: ~175 concurrent users
- **4 instances**: ~350 concurrent users  
- **6 instances**: ~525 concurrent users

### Database Scaling
- Current: db.t3.micro (1 vCPU, 1GB RAM)
- Upgrade path: db.t3.small → db.t3.medium → Aurora Serverless

### Application Scaling
- Horizontal: Add more EC2 instances
- Vertical: Upgrade to t3.medium/large
- Database: Read replicas for read-heavy workloads

## Security Best Practices

### Network Security
- Private subnets for database
- Security groups with minimal required ports
- VPC isolation

### Application Security
- Security headers in Nginx
- HTTPS termination at ALB (add SSL certificate)
- Database encryption in transit

### Access Control
- IAM roles for EC2 instances
- Principle of least privilege
- Regular security updates

## Cost Optimization Tips

### 1. Use Reserved Instances
- Save 30-50% on EC2 costs
- 1-year term recommended

### 2. Right-size Resources
- Monitor CloudWatch metrics
- Downsize over-provisioned resources
- Use Spot Instances for development

### 3. Optimize Data Transfer
- Use CloudFront CDN
- Compress responses
- Optimize images

## Troubleshooting

### Common Issues
1. **Application won't start**: Check logs in CloudWatch
2. **Database connection failed**: Verify security groups
3. **High response times**: Check CPU/memory usage
4. **502 Bad Gateway**: Check Gunicorn processes

### Debugging Commands
```bash
# Check application status
sudo supervisorctl status

# View logs
sudo supervisorctl tail -f debug-marathon:debug-marathon-5000

# Check nginx
sudo nginx -t
sudo systemctl status nginx

# Database connectivity
mysql -h YOUR-RDS-ENDPOINT -u admin -p
```

## Rollback Plan
1. Keep CloudFormation stack for easy rollback
2. Database snapshots created automatically
3. Application code versioning in S3
4. Blue-green deployment for zero-downtime updates

## Post-Migration Checklist
- [ ] Application accessible via Load Balancer URL
- [ ] Database connection working
- [ ] All features tested
- [ ] Monitoring configured
- [ ] SSL certificate installed (optional)
- [ ] Domain name configured (optional)
- [ ] Backup strategy implemented
- [ ] Cost monitoring alerts set up

## Support and Maintenance
- Monitor CloudWatch dashboards daily
- Review scaling metrics weekly
- Update security patches monthly
- Review costs and optimize quarterly