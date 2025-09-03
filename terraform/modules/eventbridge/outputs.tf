output "event_bus_name" {
  description = "EventBridge custom bus name"
  value       = aws_cloudwatch_event_bus.main.name
}

output "event_bus_arn" {
  description = "EventBridge custom bus ARN"
  value       = aws_cloudwatch_event_bus.main.arn
}

output "event_rules" {
  description = "Map of EventBridge rule names and ARNs"
  value = {
    for k, v in aws_cloudwatch_event_rule.rules : k => {
      name = v.name
      arn  = v.arn
    }
  }
}

output "eventbridge_role_arn" {
  description = "EventBridge IAM role ARN"
  value       = aws_iam_role.eventbridge.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.eventbridge.name
}

output "archive_name" {
  description = "EventBridge archive name (if enabled)"
  value       = var.enable_archive ? aws_cloudwatch_event_archive.main[0].name : null
}
