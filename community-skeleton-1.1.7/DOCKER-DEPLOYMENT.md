# UVDesk v1.1.7 Docker Deployment Guide for EC2

This guide will walk you through deploying UVDesk v1.1.7 on AWS EC2 using Docker Compose.

## Prerequisites

- AWS EC2 instance (recommended: t3.medium or larger)
- Docker and Docker Compose installed
- Domain name (optional but recommended)
- SSH access to your EC2 instance

## Quick Start

### 1. EC2 Instance Setup

1. Launch an EC2 instance:
   - **Instance Type**: t3.medium or larger (2 vCPU, 4GB RAM minimum)
   - **AMI**: Amazon Linux 2 or Ubuntu 20.04 LTS
   - **Storage**: 20GB GP2 SSD minimum
   - **Security Group**: Allow HTTP (80), HTTPS (443), SSH (22), and custom ports (8080, 8081)

2. SSH into your instance:
   ```bash
   ssh -i your-key.pem ec2-user@your-instance-ip
   ```

### 2. Install Docker and Docker Compose

For Amazon Linux 2:
```bash
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for group changes to take effect
exit
```

For Ubuntu:
```bash
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ubuntu
exit
```

### 3. Deploy UVDesk

1. Upload the UVDesk files to your EC2 instance:
   ```bash
   # Option 1: Using SCP
   scp -i your-key.pem -r community-skeleton-1.1.7/ ec2-user@your-instance-ip:/home/ec2-user/

   # Option 2: Using Git (if you have a repository)
   git clone your-uvdesk-repo
   cd your-uvdesk-repo/community-skeleton-1.1.7/
   ```

2. Configure environment variables:
   ```bash
   cd community-skeleton-1.1.7/
   cp docker-compose.env.template .env
   nano .env
   ```

3. Update the `.env` file with your settings:
   ```env
   # Database Configuration
   MYSQL_ROOT_PASSWORD=your_super_secure_root_password
   MYSQL_PASSWORD=your_secure_password
   
   # Application Configuration
   APP_SECRET=your_very_long_and_secure_secret_key_here
   UVDESK_PORT=8080
   
   # Email Configuration (example for Gmail)
   MAILER_DSN=smtp://youremail@gmail.com:yourpassword@smtp.gmail.com:587
   
   # Redis Password
   REDIS_PASSWORD=your_redis_password
   
   # Admin Configuration
   ADMIN_EMAIL=admin@yourdomain.com
   ADMIN_PASSWORD=your_admin_password
   ```

4. Start the application:
   ```bash
   # Build and start all services
   docker-compose up -d

   # Check status
   docker-compose ps

   # View logs
   docker-compose logs -f uvdesk
   ```

### 4. Access UVDesk

1. **Main Application**: `http://your-instance-ip:8080`
2. **PhpMyAdmin** (optional): `http://your-instance-ip:8081`

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MYSQL_ROOT_PASSWORD` | MySQL root password | `uvdesk_root_password` |
| `MYSQL_PASSWORD` | MySQL user password | `uvdesk_password` |
| `APP_SECRET` | Application secret key | Must be changed |
| `UVDESK_PORT` | Application port | `8080` |
| `MAILER_DSN` | Email server configuration | `smtp://localhost:25` |
| `REDIS_PASSWORD` | Redis password | `uvdesk_redis_password` |
| `TZ` | Timezone | `UTC` |

### Optional Services

To enable optional services like PhpMyAdmin:
```bash
docker-compose --profile tools up -d
```

## SSL/TLS Configuration

### Using Let's Encrypt with Nginx Proxy

1. Install Nginx:
   ```bash
   sudo yum install -y nginx  # Amazon Linux
   sudo apt install -y nginx  # Ubuntu
   ```

2. Configure Nginx proxy:
   ```nginx
   # /etc/nginx/conf.d/uvdesk.conf
   server {
       listen 80;
       server_name your-domain.com;
       
       location / {
           proxy_pass http://localhost:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

3. Install Certbot and get SSL certificate:
   ```bash
   sudo yum install -y certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```

## Maintenance Commands

### Backup Database
```bash
# Create backup
docker-compose exec db mysqldump -u root -p uvdesk > uvdesk_backup_$(date +%Y%m%d_%H%M%S).sql

# Restore backup
docker-compose exec -T db mysql -u root -p uvdesk < uvdesk_backup_file.sql
```

### Update Application
```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose up -d --build
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f uvdesk
docker-compose logs -f db
```

### Scale Services
```bash
# Scale application instances
docker-compose up -d --scale uvdesk=3
```

## Monitoring

### Health Checks
```bash
# Check service health
docker-compose ps

# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Resource Usage
```bash
# Check resource usage
docker stats

# Check disk usage
docker system df
```

## Security Considerations

1. **Change default passwords** in the `.env` file
2. **Use strong passwords** for all services
3. **Enable firewall** and only allow necessary ports
4. **Regular updates** of Docker images and host system
5. **Use SSL/TLS** for production deployments
6. **Regular backups** of database and application data

## Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure ports 8080, 3306, 6379 are not in use
2. **Memory issues**: Increase EC2 instance size if needed
3. **Database connection**: Check database logs with `docker-compose logs db`
4. **Application errors**: Check application logs with `docker-compose logs uvdesk`

### Debug Commands
```bash
# Enter container shell
docker-compose exec uvdesk /bin/bash

# Check network connectivity
docker network ls
docker network inspect uvdesk_uvdesk_network

# Check volume mounts
docker volume ls
docker volume inspect uvdesk_mysql_data
```

## Performance Optimization

### For Production Use

1. **Use external database** (RDS) for better performance
2. **Use Redis/ElastiCache** for caching
3. **Use ELB** for load balancing
4. **Use CloudFront** for CDN
5. **Use S3** for file storage
6. **Enable CloudWatch** for monitoring

### Resource Recommendations

| Environment | Instance Type | Storage | Memory |
|-------------|---------------|---------|---------|
| Development | t3.small | 20GB | 2GB |
| Staging | t3.medium | 50GB | 4GB |
| Production | t3.large+ | 100GB+ | 8GB+ |

## Support and Documentation

- [UVDesk Documentation](https://docs.uvdesk.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)

## License

This deployment configuration is provided under the same license as UVDesk Community Edition. 