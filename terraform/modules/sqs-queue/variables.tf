variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "service_name" {
  description = "Name of the service using this queue"
  type        = string
}

variable "criticality" {
  description = "Queue criticality level (critical, high, medium, low)"
  type        = string
  validation {
    condition     = contains(["critical", "high", "medium", "low"], var.criticality)
    error_message = "Criticality must be one of: critical, high, medium, low."
  }
}

variable "slo_latency" {
  description = "SLO latency requirement (e.g., 5s, 30s, 5m)"
  type        = string
}

variable "visibility_timeout" {
  description = "Visibility timeout in seconds"
  type        = number
  default     = 300
}

variable "message_retention_seconds" {
  description = "Message retention period in seconds"
  type        = number
  default     = 1209600 # 14 days
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time in seconds"
  type        = number
  default     = 20
}

variable "max_receive_count" {
  description = "Maximum receive count before moving to DLQ"
  type        = number
  default     = 3
}

variable "dlq_retention_seconds" {
  description = "DLQ message retention in seconds"
  type        = number
  default     = 1209600 # 14 days
}

# FIFO Queue Configuration
variable "fifo_queue" {
  description = "Whether this is a FIFO queue"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication for FIFO queues"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "queue_depth_threshold" {
  description = "Queue depth threshold for alarms"
  type        = number
  default     = 100
}

variable "message_age_threshold" {
  description = "Message age threshold in seconds"
  type        = number
  default     = 300
}

variable "alarm_period" {
  description = "CloudWatch alarm period in seconds"
  type        = number
  default     = 300
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarm"
  type        = number
  default     = 2
}

variable "alarm_actions" {
  description = "List of alarm actions (SNS topic ARNs)"
  type        = list(string)
  default     = []
}

variable "dlq_alarm_actions" {
  description = "List of DLQ alarm actions (SNS topic ARNs)"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
