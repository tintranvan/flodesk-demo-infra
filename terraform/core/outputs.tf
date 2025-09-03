# Core Infrastructure Outputs

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "vpc_endpoints_security_group_id" {
  description = "VPC endpoints security group ID"
  value       = module.vpc.vpc_endpoints_security_group_id
}

# ECS Cluster Outputs
output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = module.ecs_cluster.task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = module.ecs_cluster.task_role_arn
}

output "ecs_security_group_id" {
  description = "ECS tasks security group ID"
  value       = module.ecs_cluster.security_group_id
}

# API Gateway Outputs
output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_id
}

output "api_gateway_root_resource_id" {
  description = "API Gateway root resource ID"
  value       = module.api_gateway.root_resource_id
}

output "api_gateway_execution_arn" {
  description = "API Gateway execution ARN"
  value       = module.api_gateway.execution_arn
}

output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.invoke_url
}

output "api_gateway_api_key" {
  description = "API Gateway API key"
  value       = module.api_gateway.api_key_value
  sensitive   = true
}

# Shared Resources
output "shared_ecr_repository_url" {
  description = "Shared ECR repository URL"
  value       = aws_ecr_repository.shared.repository_url
}

output "terraform_state_bucket" {
  description = "Terraform state S3 bucket name"
  value       = aws_s3_bucket.terraform_state.bucket
}

# Environment Info
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
