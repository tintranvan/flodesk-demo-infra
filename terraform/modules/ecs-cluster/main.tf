# ECS Cluster Module with Mixed Capacity (On-Demand + Spot)

resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.common_tags, {
    Name = var.cluster_name
  })
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = var.fargate_base
    weight            = var.fargate_weight
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    base              = 0
    weight            = var.fargate_spot_weight
    capacity_provider = "FARGATE_SPOT"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.cluster_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-logs"
  })
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.cluster_name}-tasks"
  vpc_id      = var.vpc_id

  # Allow inbound from ALB/API Gateway
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  # Allow all outbound (for VPC endpoints)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-tasks-sg"
  })
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.cluster_name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for VPC endpoints and Secrets Manager
resource "aws_iam_role_policy" "ecs_task_execution_additional" {
  name = "${var.cluster_name}-task-execution-additional"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for ECS Tasks (application permissions)
resource "aws_iam_role" "ecs_task" {
  name = "${var.cluster_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# Basic SQS permissions for workers
resource "aws_iam_role_policy" "ecs_task_sqs" {
  name = "${var.cluster_name}-task-sqs"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}
