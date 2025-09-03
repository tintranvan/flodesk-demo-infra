output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.worker.name
}

output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.worker.id
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.worker.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.worker.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.worker.name
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.worker_task.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.worker.name
}

output "autoscaling_target_resource_id" {
  description = "Auto scaling target resource ID"
  value       = aws_appautoscaling_target.worker.resource_id
}
