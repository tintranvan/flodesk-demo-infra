# Development Environment Configuration

environment = "dev"
aws_region  = "us-east-1"

# VPC Configuration - Smaller CIDR for dev
vpc_cidr = "10.0.0.0/16"

# Private Subnets (Workers - No Internet Access)
private_subnet_cidrs = [
  "10.0.1.0/24",  # us-east-1a
  "10.0.2.0/24"   # us-east-1b
]

# Public Subnets (Load Balancers)
public_subnet_cidrs = [
  "10.0.101.0/24", # us-east-1a
  "10.0.102.0/24"  # us-east-1b
]

# ECS Mixed Capacity (20% On-Demand, 80% Spot)
ecs_capacity_providers = {
  fargate_weight      = 10
  fargate_spot_weight = 90
  fargate_base        = 0 # Minimum ECS Task Ondemand
}

# Environment-specific tags
common_tags = {
  Environment = "dev"
  Project     = "flodesk"
  Owner       = "devops-team"
  CostCenter  = "engineering"
  Backup      = "daily"
}
