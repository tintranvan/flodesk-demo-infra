# Lambda API Module with ARM64 and Web Adapter

# ECR Repository for Lambda container
resource "aws_ecr_repository" "lambda" {
  name                 = var.service_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.common_tags, {
    Name    = var.service_name
    Type    = "Lambda"
    Service = var.service_name
  })
}

# Lambda Function
resource "aws_lambda_function" "api" {
  function_name = var.service_name
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda.repository_url}:${var.image_tag}"
  
  # ARM64 for cost optimization
  architectures = ["arm64"]
  
  timeout     = var.timeout
  memory_size = var.memory_size

  environment {
    variables = merge(var.environment_variables, {
      LOG_LEVEL = var.log_level
      PORT      = "8080"
    })
  }

  # VPC Configuration for private subnets
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda
  ]

  tags = merge(var.common_tags, {
    Name    = var.service_name
    Type    = "Lambda"
    Service = var.service_name
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.service_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name    = "${var.service_name}-logs"
    Service = var.service_name
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.service_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = var.vpc_config != null ? "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" : "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}

# EventBridge permissions
resource "aws_iam_role_policy" "lambda_eventbridge" {
  name = "${var.service_name}-eventbridge"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = var.eventbridge_bus_arn
      }
    ]
  })
}

# Secrets Manager permissions
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${var.service_name}-secrets"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}

# API Gateway Integration
resource "aws_api_gateway_resource" "api" {
  count       = length(var.api_paths)
  rest_api_id = var.api_gateway_id
  parent_id   = var.api_gateway_root_resource_id
  path_part   = split("/", var.api_paths[count.index])[1] # Remove leading slash
}

resource "aws_api_gateway_method" "api" {
  count         = length(var.api_paths)
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.api[count.index].id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api" {
  count                   = length(var.api_paths)
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.api[count.index].id
  http_method             = aws_api_gateway_method.api[count.index].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

# Provisioned Concurrency (optional)
resource "aws_lambda_provisioned_concurrency_config" "api" {
  count = var.enable_provisioned_concurrency ? 1 : 0
  
  function_name                     = aws_lambda_function.api.function_name
  provisioned_concurrency_units     = var.provisioned_concurrency_units
  qualifier                        = aws_lambda_function.api.version
}
