output "queue_id" {
  description = "SQS queue ID"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.main.arn
}

output "queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.main.url
}

output "queue_name" {
  description = "SQS queue name"
  value       = aws_sqs_queue.main.name
}

output "dlq_id" {
  description = "Dead letter queue ID"
  value       = aws_sqs_queue.dlq.id
}

output "dlq_arn" {
  description = "Dead letter queue ARN"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "Dead letter queue URL"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_name" {
  description = "Dead letter queue name"
  value       = aws_sqs_queue.dlq.name
}
