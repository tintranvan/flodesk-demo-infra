output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.api.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.api.arn
}

output "lambda_invoke_arn" {
  description = "Lambda function invoke ARN"
  value       = aws_lambda_function.api.invoke_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.lambda.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.lambda.name
}

output "lambda_role_arn" {
  description = "Lambda IAM role ARN"
  value       = aws_iam_role.lambda.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.lambda.name
}
