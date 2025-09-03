variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where cluster will be created"
  type        = string
}

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

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "allowed_security_groups" {
  description = "Security groups allowed to access ECS tasks"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
