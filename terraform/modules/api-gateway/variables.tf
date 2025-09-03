variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_description" {
  description = "Description of the API Gateway"
  type        = string
  default     = "Flodesk Platform API"
}

variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "v1"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Rate Limiting Configuration
variable "quota_limit" {
  description = "API quota limit per period"
  type        = number
  default     = 10000
}

variable "quota_period" {
  description = "API quota period (DAY, WEEK, MONTH)"
  type        = string
  default     = "DAY"
}

variable "throttle_rate_limit" {
  description = "API throttle rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "throttle_burst_limit" {
  description = "API throttle burst limit"
  type        = number
  default     = 200
}

# WAF Configuration
variable "enable_waf" {
  description = "Enable WAF for API Gateway"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit per 5-minute period"
  type        = number
  default     = 2000
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
