output "api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "API Gateway REST API ARN"
  value       = aws_api_gateway_rest_api.main.arn
}

output "root_resource_id" {
  description = "API Gateway root resource ID"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}

output "execution_arn" {
  description = "API Gateway execution ARN"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "stage_arn" {
  description = "API Gateway stage ARN"
  value       = aws_api_gateway_stage.main.arn
}

output "invoke_url" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_key_id" {
  description = "API Gateway API key ID"
  value       = aws_api_gateway_api_key.main.id
}

output "api_key_value" {
  description = "API Gateway API key value"
  value       = aws_api_gateway_api_key.main.value
  sensitive   = true
}

output "usage_plan_id" {
  description = "API Gateway usage plan ID"
  value       = aws_api_gateway_usage_plan.main.id
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.api_gateway.name
}
