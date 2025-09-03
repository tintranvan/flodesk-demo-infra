# Core Infrastructure Variables

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, stg, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "flodesk"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

# ECS Configuration
variable "ecs_capacity_providers" {
  description = "ECS capacity provider configuration"
  type = object({
    fargate_weight      = number
    fargate_spot_weight = number
    fargate_base        = number
  })
  default = {
    fargate_weight      = 20  # 20% On-Demand
    fargate_spot_weight = 80  # 80% Spot
    fargate_base        = 1   # Minimum On-Demand instances
  }
}

# Tagging
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
