# ZeroTouch-to-Prod - Simple Design Document

## 📋 **Overview**

**Project**: ZeroTouch-to-Prod  
**Purpose**: Automated deployment pipeline from code commit to production  
**Tech Stack**: GitHub Actions, Docker, AWS ECS, nginx  
**Deployment Model**: Zero-touch, multi-environment CI/CD  

---

## 🎯 **Problem & Solution**

### **Problem**
- Manual deployment and promotion to environments
- No automated testing or validation
- Do not want to maintain terraform code in project repo
- Manual credential management

### **Solution**
- Multi-environment promotion (dev → qa → prod)
- Automated health checks and validation

---

## 🏗️ **High-Level Architecture**

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub    │───▶│   GitHub Actions │───▶│   AWS ECR       │
│ Repository  │    │   CI/CD Pipeline │    │ (Image Registry)│
└─────────────┘    └──────────────────┘    └─────────────────┘
                            │                        │
                            ▼                        │
                   ┌──────────────────┐              │
                   │  Build & Test    │              │
                   │  Docker Image    │              │
                   └──────────────────┘              │
                            │                        │
                            ▼                        │
      ┌─────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────────────┐
│                    AWS ECS Deployment                      │
├─────────────────┬─────────────────┬─────────────────────────┤
│   DEV Environment  │  QA Environment │  PROD Environment     │
│   ┌─────────────┐  │  ┌─────────────┐ │  ┌─────────────────┐ │
│   │ ECS Service │  │  │ ECS Service │ │  │  ECS Service    │ │
│   │ + ALB       │  │  │ + ALB       │ │  │  + ALB          │ │
│   └─────────────┘  │  └─────────────┘ │  └─────────────────┘ │
└─────────────────────┴─────────────────┴─────────────────────┘
```

---

## 📁 **Project Structure**

```
zerotouch-to-prod/
├── application/                    # Application code & config
│   ├── Dockerfile                 # Container definition
│   ├── nginx.conf                 # Web server config
│   └── src/                       # Static website files
│       ├── index.html             # Home page
│       └── about.html             # About page
├── .github/workflows/             # CI/CD pipeline
│   └── deploy-to-prod.yml         # Main deployment workflow
└── scripts/                       # Helper scripts (future use)
```

---

## 🔄 **Deployment Flow**

### **1. Trigger**
- Developer pushes code to `main` branch
- Only changes in `application/**` trigger deployment
- Manual deployment also possible via GitHub UI

### **2. Build Phase**
```yaml
Build Process:
1. Checkout code
2. Set up Docker
3. Login to AWS ECR
4. Build Docker image (nginx + static content)
5. Tag with commit SHA
6. Push to ECR registry
```

### **3. Deploy Phase (Sequential)**
```yaml
Environment Promotion:
DEV → QA → PROD

For each environment:
1. Update ECS task definition
2. Deploy to ECS service
3. Wait for service stability
4. Run health checks
5. Validate deployment success
```

### **4. Validation**
- Health endpoint checks (`/health`)
- Service stability validation
- ALB DNS resolution
- Response time verification

