variable "service_name" {
  description = "Name of the API service"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag for Lambda"
  type        = string
  default     = "latest"
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
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

variable "environment_variables" {
  description = "Environment variables for Lambda"
  type        = map(string)
  default     = {}
}

# VPC Configuration
variable "vpc_config" {
  description = "VPC configuration for Lambda"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# API Gateway Configuration
variable "api_gateway_id" {
  description = "API Gateway REST API ID"
  type        = string
}

variable "api_gateway_root_resource_id" {
  description = "API Gateway root resource ID"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN"
  type        = string
}

variable "api_paths" {
  description = "List of API paths for this service"
  type        = list(string)
}

# EventBridge Configuration
variable "eventbridge_bus_arn" {
  description = "EventBridge custom bus ARN"
  type        = string
}

# Provisioned Concurrency Configuration
variable "enable_provisioned_concurrency" {
  description = "Enable provisioned concurrency to eliminate cold starts"
  type        = bool
  default     = false
}

variable "provisioned_concurrency_units" {
  description = "Number of provisioned concurrency units"
  type        = number
  default     = 1
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
