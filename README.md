# Flodesk Infrastructure

DevOps repository for Flodesk platform infrastructure management.

## Architecture

```
User → API Gateway → Lambda APIs → EventBridge → SQS → ECS Fargate Workers
```

## Repository Structure

```
flodesk-infra/
├── terraform/
│   ├── core/           # Core infrastructure (VPC, API Gateway, ECS Cluster)
│   ├── modules/        # Reusable Terraform modules
│   └── environments/   # Environment-specific configurations
├── scripts/            # Deployment and utility scripts
├── monitoring/         # Grafana dashboards and alerting rules
└── .github/workflows/  # CI/CD pipelines
```

## Core Infrastructure Components

- **VPC with Private Subnets** - Zero internet access for workers
- **VPC Endpoints** - ECR, SQS, CloudWatch, S3 (cost optimization)
- **API Gateway** - Centralized API management with rate limiting
- **ECS Fargate Cluster** - ARM64 workers with mixed capacity (20% On-Demand, 80% Spot)
- **EventBridge** - Message routing and event-driven architecture
- **SQS Queues** - Tiered queues (Critical, High-Volume, Batch)

## Cost Optimization Features

- ARM64 Lambda + ECS Fargate (20% cost savings)
- ECR Private Endpoints (eliminate NAT Gateway costs)
- Mixed capacity ECS: 20% On-Demand, 80% Spot instances (up to 70% savings)
- Private subnets with VPC endpoints

## Security Features

- Network isolation (private subnets, no internet access)
- Secrets Manager integration
- IAM least privilege access
- API Gateway rate limiting and WAF

## Usage

1. **Core Infrastructure**: Deploy shared resources
2. **Service Deployment**: Triggered from monorepo via service.yaml
3. **Monitoring**: Automated dashboards and SLO tracking

## Getting Started

```bash
# Deploy core infrastructure
cd terraform/core
terraform init
terraform plan
terraform apply
```
