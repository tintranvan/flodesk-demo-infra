# SQS Queue Module with Tiered Strategy

# Main Queue
resource "aws_sqs_queue" "main" {
  name                       = var.queue_name
  visibility_timeout_seconds = var.visibility_timeout
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  max_receive_count         = var.max_receive_count

  # FIFO configuration
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  tags = merge(var.common_tags, {
    Name        = var.queue_name
    Criticality = var.criticality
    SLOLatency  = var.slo_latency
    Service     = var.service_name
  })
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.queue_name}-dlq"
  message_retention_seconds = var.dlq_retention_seconds
  
  # FIFO configuration for DLQ
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  tags = merge(var.common_tags, {
    Name        = "${var.queue_name}-dlq"
    Criticality = var.criticality
    Service     = var.service_name
    Type        = "DeadLetterQueue"
  })
}

# Redrive Policy
resource "aws_sqs_queue_redrive_policy" "main" {
  queue_url = aws_sqs_queue.main.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

# CloudWatch Alarms based on criticality
resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  alarm_name          = "${var.queue_name}-depth-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.queue_depth_threshold
  alarm_description   = "Queue depth alarm for ${var.queue_name}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  tags = merge(var.common_tags, {
    Name        = "${var.queue_name}-depth-alarm"
    Criticality = var.criticality
  })
}

resource "aws_cloudwatch_metric_alarm" "message_age" {
  alarm_name          = "${var.queue_name}-age-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = var.alarm_period
  statistic           = "Maximum"
  threshold           = var.message_age_threshold
  alarm_description   = "Message age alarm for ${var.queue_name}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  tags = merge(var.common_tags, {
    Name        = "${var.queue_name}-age-alarm"
    Criticality = var.criticality
  })
}

# DLQ Alarm
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.queue_name}-dlq-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Messages in DLQ for ${var.queue_name}"
  alarm_actions       = var.dlq_alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  tags = merge(var.common_tags, {
    Name        = "${var.queue_name}-dlq-alarm"
    Criticality = "critical"
  })
}
