variable "bus_name" {
  description = "Name of the EventBridge custom bus"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Event Rules Configuration
variable "event_rules" {
  description = "Map of EventBridge rules configuration"
  type = map(object({
    description   = string
    event_type    = string
    criticality   = string
    enabled       = bool
    event_pattern = any
  }))
  default = {}
}

# SQS Targets Configuration
variable "sqs_targets" {
  description = "Map of SQS targets for EventBridge rules"
  type = map(object({
    rule_name    = string
    queue_arn    = string
    dlq_arn      = string
    input_transformer = object({
      input_paths    = map(string)
      input_template = string
    })
    retry_policy = object({
      maximum_event_age_in_seconds = number
      maximum_retry_attempts       = number
    })
  }))
  default = {}
}

variable "allowed_queue_arns" {
  description = "List of SQS queue ARNs that EventBridge can send messages to"
  type        = list(string)
  default     = []
}

# Archive Configuration
variable "enable_archive" {
  description = "Enable EventBridge archive for event replay"
  type        = bool
  default     = false
}

variable "archive_retention_days" {
  description = "Archive retention period in days"
  type        = number
  default     = 30
}

# Monitoring Configuration
variable "alarm_actions" {
  description = "List of alarm actions (SNS topic ARNs)"
  type        = list(string)
  default     = []
}

variable "critical_alarm_actions" {
  description = "List of critical alarm actions (SNS topic ARNs)"
  type        = list(string)
  default     = []
}

variable "critical_event_threshold" {
  description = "Threshold for critical event processing alarms"
  type        = number
  default     = 100
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
