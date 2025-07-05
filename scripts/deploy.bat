@echo off
REM Deploy Infrastructure and Application Script for Windows
REM This script deploys the complete ECS infrastructure and application

echo.
echo 🚀 Starting ECS Infrastructure and Application Deployment
echo ==========================================================
echo.

REM Check if required tools are installed
echo [INFO] Checking prerequisites...

where terraform >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Terraform is not installed. Please install Terraform first.
    exit /b 1
)

where aws >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] AWS CLI is not installed. Please install AWS CLI first.
    exit /b 1
)

where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed. Please install Docker first.
    exit /b 1
)

echo [SUCCESS] All prerequisites are installed

REM Check AWS credentials
echo [INFO] Checking AWS credentials...
aws sts get-caller-identity >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] AWS credentials not configured. Please run 'aws configure' first.
    exit /b 1
)

for /f "tokens=*" %%a in ('aws sts get-caller-identity --query Account --output text') do set AWS_ACCOUNT_ID=%%a
for /f "tokens=*" %%a in ('aws configure get region 2^>nul ^|^| echo us-east-1') do set AWS_REGION=%%a

echo [SUCCESS] AWS credentials configured for account: %AWS_ACCOUNT_ID% in region: %AWS_REGION%

REM Deploy base infrastructure
echo [INFO] Deploying base infrastructure...
cd terraform_infra

echo [INFO] Initializing Terraform...
terraform init
if %errorlevel% neq 0 (
    echo [ERROR] Terraform init failed
    exit /b 1
)

echo [INFO] Planning base infrastructure...
terraform plan -var-file="dev.tfvars" -out="base-plan.tfplan"
if %errorlevel% neq 0 (
    echo [ERROR] Terraform plan failed
    exit /b 1
)

echo [INFO] Applying base infrastructure...
terraform apply "base-plan.tfplan"
if %errorlevel% neq 0 (
    echo [ERROR] Terraform apply failed
    exit /b 1
)

echo [SUCCESS] Base infrastructure deployed successfully

REM Build and push Docker image
cd ..
echo [INFO] Building and pushing Docker image...

REM Check if ECR repository exists, if not create it
set ECR_REPO_NAME=my-app-dev
aws ecr describe-repositories --repository-names %ECR_REPO_NAME% --region %AWS_REGION% >nul 2>nul
if %errorlevel% neq 0 (
    echo [INFO] Creating ECR repository...
    aws ecr create-repository --repository-name %ECR_REPO_NAME% --region %AWS_REGION%
)

set ECR_REPO_URL=%AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/%ECR_REPO_NAME%
echo [INFO] ECR Repository: %ECR_REPO_URL%

REM Login to ECR
echo [INFO] Logging into ECR...
for /f "tokens=*" %%a in ('aws ecr get-login-password --region %AWS_REGION%') do docker login --username AWS --password-stdin %ECR_REPO_URL% <nul

REM Build Docker image
echo [INFO] Building Docker image...
cd application
docker build -t my-app:latest .
docker tag my-app:latest %ECR_REPO_URL%:latest

REM Push to ECR
echo [INFO] Pushing image to ECR...
docker push %ECR_REPO_URL%:latest
if %errorlevel% neq 0 (
    echo [ERROR] Docker push failed
    exit /b 1
)

echo [SUCCESS] Docker image built and pushed successfully

REM Deploy application
cd ..\terraform_infra
echo [INFO] Deploying application to ECS...

REM Update app_image in tfvars with ECR image
copy dev_application.tfvars dev_application_deploy.tfvars
powershell -Command "(Get-Content dev_application_deploy.tfvars) -replace 'app_image.*=.*', 'app_image = \"%ECR_REPO_URL%:latest\"' | Set-Content dev_application_deploy.tfvars"

REM Plan application deployment
echo [INFO] Planning application deployment...
terraform plan -var-file="dev_application_deploy.tfvars" -out="app-plan.tfplan"
if %errorlevel% neq 0 (
    echo [ERROR] Application terraform plan failed
    exit /b 1
)

REM Apply application deployment
echo [INFO] Applying application deployment...
terraform apply "app-plan.tfplan"
if %errorlevel% neq 0 (
    echo [ERROR] Application terraform apply failed
    exit /b 1
)

REM Clean up temporary file
del dev_application_deploy.tfvars

echo [SUCCESS] Application deployed successfully

REM Get application URL
echo [INFO] Getting application URL...
for /f "tokens=*" %%a in ('terraform output -raw alb_dns_name 2^>nul') do set ALB_DNS=%%a

if not "%ALB_DNS%"=="" (
    echo.
    echo [SUCCESS] Application deployed successfully!
    echo.
    echo 🌐 Application URLs:
    echo    Home Page: http://%ALB_DNS%
    echo    About Page: http://%ALB_DNS%/about.html
    echo    Health Check: http://%ALB_DNS%/health
    echo.
    echo [WARNING] Note: It may take a few minutes for the load balancer to become healthy
) else (
    echo [WARNING] Could not retrieve application URL. Check AWS Console for ALB DNS name.
)

cd ..

echo.
echo [SUCCESS] 🎉 Deployment completed successfully!
echo.
echo [INFO] Next steps:
echo 1. Visit your application URLs shown above
echo 2. Check CloudWatch logs for application logs
echo 3. Monitor ECS service in AWS Console
echo 4. Set up GitHub Actions for automated deployments
echo.

pause
