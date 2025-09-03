# EventBridge Module for Event-Driven Architecture

# Custom EventBridge Bus
resource "aws_cloudwatch_event_bus" "main" {
  name = var.bus_name

  tags = merge(var.common_tags, {
    Name = var.bus_name
  })
}

# EventBridge Rules for different event patterns
resource "aws_cloudwatch_event_rule" "rules" {
  for_each = var.event_rules

  name           = each.key
  description    = each.value.description
  event_bus_name = aws_cloudwatch_event_bus.main.name
  
  event_pattern = jsonencode(each.value.event_pattern)
  state         = each.value.enabled ? "ENABLED" : "DISABLED"

  tags = merge(var.common_tags, {
    Name        = each.key
    EventType   = each.value.event_type
    Criticality = each.value.criticality
  })
}

# EventBridge Targets (SQS Queues)
resource "aws_cloudwatch_event_target" "sqs_targets" {
  for_each = var.sqs_targets

  rule           = aws_cloudwatch_event_rule.rules[each.value.rule_name].name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = each.key
  arn            = each.value.queue_arn

  # Message transformation
  dynamic "input_transformer" {
    for_each = each.value.input_transformer != null ? [each.value.input_transformer] : []
    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }

  # Dead letter queue configuration
  dynamic "dead_letter_config" {
    for_each = each.value.dlq_arn != null ? [each.value.dlq_arn] : []
    content {
      arn = dead_letter_config.value
    }
  }

  # Retry policy
  dynamic "retry_policy" {
    for_each = each.value.retry_policy != null ? [each.value.retry_policy] : []
    content {
      maximum_event_age_in_seconds = retry_policy.value.maximum_event_age_in_seconds
      maximum_retry_attempts       = retry_policy.value.maximum_retry_attempts
    }
  }
}

# IAM Role for EventBridge to access SQS
resource "aws_iam_role" "eventbridge" {
  name = "${var.bus_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# IAM Policy for EventBridge to send messages to SQS
resource "aws_iam_role_policy" "eventbridge_sqs" {
  count = length(var.allowed_queue_arns) > 0 ? 1 : 0
  
  name = "${var.bus_name}-sqs-policy"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.allowed_queue_arns
      }
    ]
  })
}

# CloudWatch Log Group for EventBridge
resource "aws_cloudwatch_log_group" "eventbridge" {
  name              = "/aws/events/${var.bus_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.bus_name}-logs"
  })
}

# EventBridge Archive for event replay (optional)
resource "aws_cloudwatch_event_archive" "main" {
  count = var.enable_archive ? 1 : 0

  name             = "${var.bus_name}-archive"
  event_source_arn = aws_cloudwatch_event_bus.main.arn
  description      = "Archive for ${var.bus_name} events"
  retention_days   = var.archive_retention_days

  event_pattern = jsonencode({
    account = [data.aws_caller_identity.current.account_id]
  })

  # tags not supported in older Terraform versions
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# CloudWatch Metrics for EventBridge monitoring
resource "aws_cloudwatch_metric_alarm" "failed_invocations" {
  for_each = var.event_rules

  alarm_name          = "${each.key}-failed-invocations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FailedInvocations"
  namespace           = "AWS/Events"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Failed invocations for EventBridge rule ${each.key}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    RuleName = aws_cloudwatch_event_rule.rules[each.key].name
  }

  tags = merge(var.common_tags, {
    Name        = "${each.key}-failed-invocations"
    Criticality = each.value.criticality
  })
}

# Custom metrics for event processing
resource "aws_cloudwatch_metric_alarm" "event_processing_latency" {
  for_each = { for k, v in var.event_rules : k => v if v.criticality == "critical" }

  alarm_name          = "${each.key}-processing-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MatchedEvents"
  namespace           = "AWS/Events"
  period              = 300
  statistic           = "Average"
  threshold           = var.critical_event_threshold
  alarm_description   = "High event processing for critical rule ${each.key}"
  alarm_actions       = var.critical_alarm_actions

  dimensions = {
    RuleName = aws_cloudwatch_event_rule.rules[each.key].name
  }

  tags = merge(var.common_tags, {
    Name        = "${each.key}-processing-latency"
    Criticality = "critical"
  })
}
