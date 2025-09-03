# Production Environment Configuration

environment = "prod"
aws_region  = "us-east-1"

# VPC Configuration - Larger CIDR for production
vpc_cidr = "10.2.0.0/16"

# Private Subnets (Workers - No Internet Access)
private_subnet_cidrs = [
  "10.2.1.0/24",  # us-east-1a
  "10.2.2.0/24",  # us-east-1b
]

# Public Subnets (Load Balancers)
public_subnet_cidrs = [
  "10.2.101.0/24", # us-east-1a
  "10.2.102.0/24", # us-east-1b
]

# ECS Mixed Capacity (50% On-Demand, 50% Spot for production reliability)
ecs_capacity_providers = {
  fargate_weight      = 50
  fargate_spot_weight = 50
  fargate_base        = 3
}

# Environment-specific tags
common_tags = {
  Environment = "prod"
  Project     = "flodesk"
  Owner       = "devops-team"
  CostCenter  = "production"
  Backup      = "continuous"
  Compliance  = "required"
}
