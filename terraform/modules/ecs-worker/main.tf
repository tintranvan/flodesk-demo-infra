# ECS Worker Module for Background Processing

# ECR Repository for Worker container
resource "aws_ecr_repository" "worker" {
  name                 = var.service_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.common_tags, {
    Name    = var.service_name
    Type    = "Worker"
    Service = var.service_name
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "worker" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn           = aws_iam_role.worker_task.arn

  # ARM64 for cost optimization
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name  = var.service_name
      image = "${aws_ecr_repository.worker.repository_url}:${var.image_tag}"
      
      essential = true
      
      environment = [
        for key, value in merge(var.environment_variables, {
          LOG_LEVEL        = var.log_level
          WORKER_INTERVAL  = var.worker_interval
          SQS_QUEUE_URL    = var.sqs_queue_url
        }) : {
          name  = key
          value = value
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command = ["CMD-SHELL", "echo 'healthy'"]
        interval = 30
        timeout = 5
        retries = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.common_tags, {
    Name    = var.service_name
    Type    = "Worker"
    Service = var.service_name
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name    = "${var.service_name}-logs"
    Service = var.service_name
  })
}

# ECS Service
resource "aws_ecs_service" "worker" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.desired_count

  # Mixed capacity strategy (20% On-Demand, 80% Spot)
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight           = var.fargate_weight
    base             = var.fargate_base
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight           = var.fargate_spot_weight
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false # Private subnets
  }

  # Auto Scaling based on SQS queue depth
  depends_on = [aws_appautoscaling_target.worker]

  tags = merge(var.common_tags, {
    Name    = var.service_name
    Type    = "Worker"
    Service = var.service_name
  })
}

# IAM Role for Worker Task
resource "aws_iam_role" "worker_task" {
  name = "${var.service_name}-task-role"

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

# SQS permissions for worker
resource "aws_iam_role_policy" "worker_sqs" {
  name = "${var.service_name}-sqs"
  role = aws_iam_role.worker_task.id

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
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# Secrets Manager permissions
resource "aws_iam_role_policy" "worker_secrets" {
  name = "${var.service_name}-secrets"
  role = aws_iam_role.worker_task.id

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

# Auto Scaling Target
resource "aws_appautoscaling_target" "worker" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.worker]
}

# Auto Scaling Policy based on SQS Queue Depth
resource "aws_appautoscaling_policy" "worker_scale_up" {
  name               = "${var.service_name}-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.target_queue_depth

    customized_metric_specification {
      metric_name = "ApproximateNumberOfVisibleMessages"
      namespace   = "AWS/SQS"
      statistic   = "Average"

      dimensions = {
        QueueName = var.sqs_queue_name
      }
    }

    scale_out_cooldown  = var.scale_out_cooldown
    scale_in_cooldown   = var.scale_in_cooldown
  }
}
