# Staging Environment Configuration

environment = "stg"
aws_region  = "us-east-1"

# VPC Configuration - Medium CIDR for staging
vpc_cidr = "10.1.0.0/16"

# Private Subnets (Workers - No Internet Access)
private_subnet_cidrs = [
  "10.1.1.0/24",  # us-east-1a
  "10.1.2.0/24",  # us-east-1b
  "10.1.3.0/24"   # us-east-1c
]

# Public Subnets (Load Balancers)
public_subnet_cidrs = [
  "10.1.101.0/24", # us-east-1a
  "10.1.102.0/24", # us-east-1b
  "10.1.103.0/24"  # us-east-1c
]

# ECS Mixed Capacity (30% On-Demand, 70% Spot for staging)
ecs_capacity_providers = {
  fargate_weight      = 30
  fargate_spot_weight = 70
  fargate_base        = 2
}

# Environment-specific tags
common_tags = {
  Environment = "stg"
  Project     = "flodesk"
  Owner       = "devops-team"
  CostCenter  = "engineering"
  Backup      = "weekly"
}
