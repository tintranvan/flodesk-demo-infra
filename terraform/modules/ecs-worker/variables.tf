variable "service_name" {
  description = "Name of the worker service"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS service"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

# Container Configuration
variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "cpu" {
  description = "CPU units for the task"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MB for the task"
  type        = number
  default     = 512
}

variable "log_level" {
  description = "Log level for the application"
  type        = string
  default     = "info"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "worker_interval" {
  description = "Worker polling interval"
  type        = string
  default     = "10s"
}

variable "environment_variables" {
  description = "Environment variables for the worker"
  type        = map(string)
  default     = {}
}

# SQS Configuration
variable "sqs_queue_url" {
  description = "SQS queue URL for the worker"
  type        = string
}

variable "sqs_queue_arn" {
  description = "SQS queue ARN for IAM permissions"
  type        = string
}

variable "sqs_queue_name" {
  description = "SQS queue name for auto scaling"
  type        = string
}

# Scaling Configuration
variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

variable "target_queue_depth" {
  description = "Target queue depth for auto scaling"
  type        = number
  default     = 10
}

variable "scale_out_cooldown" {
  description = "Scale out cooldown in seconds"
  type        = number
  default     = 300
}

variable "scale_in_cooldown" {
  description = "Scale in cooldown in seconds"
  type        = number
  default     = 300
}

# Capacity Provider Configuration
variable "fargate_weight" {
  description = "Weight for Fargate On-Demand capacity provider"
  type        = number
  default     = 20
}

variable "fargate_spot_weight" {
  description = "Weight for Fargate Spot capacity provider"
  type        = number
  default     = 80
}

variable "fargate_base" {
  description = "Base number of Fargate On-Demand instances"
  type        = number
  default     = 1
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
