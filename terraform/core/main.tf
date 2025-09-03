

# Local values
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# VPC Module
module "vpc" {
  source = "../modules/vpc"

  name_prefix            = local.name_prefix
  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  private_subnet_cidrs  = var.private_subnet_cidrs
  public_subnet_cidrs   = var.public_subnet_cidrs
  common_tags           = var.common_tags
}

# ECS Cluster Module
module "ecs_cluster" {
  source = "../modules/ecs-cluster"

  cluster_name            = "${local.name_prefix}-cluster"
  vpc_id                 = module.vpc.vpc_id
  fargate_weight         = var.ecs_capacity_providers.fargate_weight
  fargate_spot_weight    = var.ecs_capacity_providers.fargate_spot_weight
  fargate_base           = var.ecs_capacity_providers.fargate_base
  log_retention_days     = 7
  allowed_security_groups = []
  common_tags            = var.common_tags
}

# API Gateway Module
module "api_gateway" {
  source = "../modules/api-gateway"

  api_name           = "${local.name_prefix}-api"
  api_description    = "Flodesk Platform API Gateway - ${var.environment}"
  stage_name         = "v1"
  log_retention_days = 7
  
  # Rate limiting for email platform
  quota_limit           = 100000  # 100K requests per day
  quota_period          = "DAY"
  throttle_rate_limit   = 1000    # 1K requests per second
  throttle_burst_limit  = 2000    # 2K burst
  
  # WAF for security
  enable_waf     = true
  waf_rate_limit = 10000  # 10K requests per 5-minute period
  
  common_tags = var.common_tags
}

# S3 Bucket for Terraform State (if not exists)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "flodesk-terraform-state-647272350116"

  tags = merge(var.common_tags, {
    Name        = "Terraform State Bucket"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Shared ECR Repository
resource "aws_ecr_repository" "shared" {
  name                 = "${local.name_prefix}-shared"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-shared-ecr"
  })
}
