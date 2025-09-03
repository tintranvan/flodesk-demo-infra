# Core Infrastructure for Flodesk Platform
# Architecture: API Gateway → Lambda → EventBridge → SQS → ECS Fargate Workers

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "terraform-state-647272350116"
    key            = "core/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    #profile        = "esoftvn-reseraching"
  }
}

provider "aws" {
  region = var.aws_region
  #profile = "esoftvn-reseraching"
  
  default_tags {
    tags = merge(var.common_tags, {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DevOps"
    })
  }
}