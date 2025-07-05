# ECS Demo Application

A containerized Nginx web application with 2 pages, deployed on AWS ECS using Terraform and GitHub Actions.

## 🌟 Features

- **Modern Web Interface**: Responsive design with beautiful glassmorphism effects
- **Multi-Page Application**: Home page and About page with navigation
- **Health Monitoring**: Built-in health check endpoint
- **Security Headers**: Nginx configured with security best practices
- **Lightweight**: Alpine Linux base image for minimal resource usage

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│ GitHub Actions  │───▶│   AWS ECR       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Users/Web     │◀───│      ALB        │◀───│   ECS Fargate   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📁 Project Structure

```
application/
├── Dockerfile              # Container definition
├── nginx.conf             # Nginx configuration
├── src/                   # Website source files
│   ├── index.html         # Home page
│   └── about.html         # About page
└── README.md             # This file
```

## 🐳 Docker Configuration

The application uses a multi-stage Docker build with:
- **Base Image**: `nginx:alpine` (lightweight and secure)
- **Custom Content**: Static HTML pages with modern CSS
- **Health Checks**: Built-in wellness monitoring
- **Security**: Optimized Nginx configuration

### Build and Run Locally

```bash
# Build the Docker image
docker build -t my-app:latest .

# Run the container
docker run -p 8080:80 my-app:latest

# Visit http://localhost:8080
```

## 🚀 Deployment Process

### Automated CI/CD Pipeline

The application automatically deploys when changes are pushed to the `application/` folder:

1. **Trigger**: Push to `main` or `develop` branch
2. **Build**: GitHub Actions builds Docker image
3. **Push**: Image pushed to AWS ECR
4. **Deploy**: ECS service updated with new image
5. **Verify**: Health checks confirm deployment

### Manual Deployment

If you need to deploy manually:

```bash
# Login to AWS ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and tag image
docker build -t my-app-dev:latest .
docker tag my-app-dev:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app-dev:latest

# Push to ECR
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app-dev:latest

# Update ECS service
aws ecs update-service --cluster base-infra-dev --service my-app-dev --force-new-deployment
```

## 🔧 Configuration

### Environment Variables

The application supports these environment variables:

- `NODE_ENV`: Environment mode (development/production)
- `LOG_LEVEL`: Logging verbosity (info/debug/error)
- `PORT`: Application port (default: 80)

### Health Check

The application provides a health check endpoint:

```bash
curl http://your-alb-url/health
# Returns: healthy
```

## 📊 Monitoring

### CloudWatch Logs

Application logs are automatically sent to CloudWatch:
- **Log Group**: `/aws/ecs/base-infra-dev/my-app-dev`
- **Retention**: 1 day (free tier optimized)

### Metrics

Monitor key metrics in CloudWatch:
- ECS service CPU/Memory utilization
- ALB request count and response times
- Health check status

## 🔒 Security Features

- **Security Headers**: HSTS, XSS Protection, Content Security Policy
- **Least Privilege**: Minimal container permissions
- **Network Security**: Security groups with restricted access
- **Image Scanning**: ECR vulnerability scanning (can be enabled)

## 💰 Cost Optimization

The application is configured for AWS Free Tier:
- **Compute**: 0.25 vCPU, 0.5 GB memory
- **Logs**: 1-day retention
- **Monitoring**: Basic metrics only
- **Storage**: No persistent volumes

## 🐛 Troubleshooting

### Common Issues

1. **Container won't start**:
   ```bash
   # Check ECS service events
   aws ecs describe-services --cluster base-infra-dev --services my-app-dev
   ```

2. **Health check failing**:
   ```bash
   # Test health endpoint locally
   docker run -p 8080:80 my-app:latest
   curl http://localhost:8080/health
   ```

3. **Deployment stuck**:
   ```bash
   # Force new deployment
   aws ecs update-service --cluster base-infra-dev --service my-app-dev --force-new-deployment
   ```

### Logs

View application logs:
```bash
# Get task ARN
TASK_ARN=$(aws ecs list-tasks --cluster base-infra-dev --service-name my-app-dev --query 'taskArns[0]' --output text)

# View logs
aws logs tail /aws/ecs/base-infra-dev/my-app-dev --follow
```

## 🔄 Development Workflow

1. **Make changes** to files in `application/` folder
2. **Commit and push** to GitHub
3. **GitHub Actions** automatically builds and deploys
4. **Monitor** the deployment in AWS Console
5. **Test** the application at the ALB URL

## 📚 Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
