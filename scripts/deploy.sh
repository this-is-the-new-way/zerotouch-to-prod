#!/bin/bash

# Deploy Infrastructure and Application Script
# This script deploys the complete ECS infrastructure and application

set -e

echo "🚀 Starting ECS Infrastructure and Application Deployment"
echo "=========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Check AWS credentials
check_aws_credentials() {
    print_status "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    
    print_success "AWS credentials configured for account: $AWS_ACCOUNT_ID in region: $AWS_REGION"
}

# Deploy base infrastructure
deploy_infrastructure() {
    print_status "Deploying base infrastructure..."
    
    cd terraform_infra
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan base infrastructure
    print_status "Planning base infrastructure..."
    terraform plan -var-file="dev.tfvars" -out="base-plan.tfplan"
    
    # Apply base infrastructure
    print_status "Applying base infrastructure..."
    terraform apply "base-plan.tfplan"
    
    print_success "Base infrastructure deployed successfully"
    
    cd ..
}

# Build and push Docker image
build_and_push_image() {
    print_status "Building and pushing Docker image..."
    
    # Get ECR repository URL
    cd terraform_infra
    ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
    cd ..
    
    if [ -z "$ECR_REPO_URL" ]; then
        print_warning "ECR repository not found in Terraform output. Creating ECR repository..."
        
        ECR_REPO_NAME="my-app-dev"
        aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION || \
        aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION
        
        ECR_REPO_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME"
    fi
    
    print_status "ECR Repository: $ECR_REPO_URL"
    
    # Login to ECR
    print_status "Logging into ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL
    
    # Build Docker image
    print_status "Building Docker image..."
    cd application
    docker build -t my-app:latest .
    docker tag my-app:latest $ECR_REPO_URL:latest
    
    # Push to ECR
    print_status "Pushing image to ECR..."
    docker push $ECR_REPO_URL:latest
    
    print_success "Docker image built and pushed successfully"
    
    cd ..
}

# Deploy application
deploy_application() {
    print_status "Deploying application to ECS..."
    
    cd terraform_infra
    
    # Update app_image in tfvars with ECR image
    ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/my-app-dev")
    
    # Create a temporary tfvars file with updated image
    cp dev_application.tfvars dev_application_deploy.tfvars
    sed -i "s|app_image.*=.*|app_image = \"$ECR_REPO_URL:latest\"|" dev_application_deploy.tfvars
    
    # Plan application deployment
    print_status "Planning application deployment..."
    terraform plan -var-file="dev_application_deploy.tfvars" -out="app-plan.tfplan"
    
    # Apply application deployment
    print_status "Applying application deployment..."
    terraform apply "app-plan.tfplan"
    
    # Clean up temporary file
    rm -f dev_application_deploy.tfvars
    
    print_success "Application deployed successfully"
    
    cd ..
}

# Get application URL
get_application_url() {
    print_status "Getting application URL..."
    
    cd terraform_infra
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    cd ..
    
    if [ -n "$ALB_DNS" ]; then
        print_success "Application deployed successfully!"
        echo ""
        echo "🌐 Application URLs:"
        echo "   Home Page: http://$ALB_DNS"
        echo "   About Page: http://$ALB_DNS/about.html"
        echo "   Health Check: http://$ALB_DNS/health"
        echo ""
        print_warning "Note: It may take a few minutes for the load balancer to become healthy"
    else
        print_warning "Could not retrieve application URL. Check AWS Console for ALB DNS name."
    fi
}

# Test deployment
test_deployment() {
    print_status "Testing deployment..."
    
    cd terraform_infra
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    cd ..
    
    if [ -n "$ALB_DNS" ]; then
        print_status "Waiting for application to be ready..."
        sleep 30
        
        # Test health endpoint
        for i in {1..5}; do
            if curl -f -s "http://$ALB_DNS/health" > /dev/null; then
                print_success "Health check passed!"
                break
            else
                print_warning "Health check attempt $i failed, retrying in 10 seconds..."
                sleep 10
            fi
        done
    fi
}

# Main execution
main() {
    echo ""
    print_status "Starting deployment process..."
    echo ""
    
    check_prerequisites
    check_aws_credentials
    deploy_infrastructure
    build_and_push_image
    deploy_application
    get_application_url
    test_deployment
    
    echo ""
    print_success "🎉 Deployment completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Visit your application URLs shown above"
    echo "2. Check CloudWatch logs for application logs"
    echo "3. Monitor ECS service in AWS Console"
    echo "4. Set up GitHub Actions for automated deployments"
    echo ""
}

# Execute main function
main "$@"
