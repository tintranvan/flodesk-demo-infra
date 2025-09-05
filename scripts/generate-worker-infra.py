#!/usr/bin/env python3

import yaml
import sys
import os

def generate_worker_terraform(service_path, environment):
    # Read service.yaml
    service_yaml_path = os.path.join(service_path, 'service.yaml')
    with open(service_yaml_path, 'r') as f:
        service_config = yaml.safe_load(f)
    
    # Get service name and config
    name = service_config['name']
    
    # Get environment-specific config
    env_config = service_config.get('environments', {}).get(environment, {})
    
    # Merge base and environment config
    resources = {**service_config.get('resources', {}), **env_config.get('resources', {})}
    scaling = {**service_config.get('scaling', {}), **env_config.get('scaling', {})}
    deployment = {**service_config.get('deployment', {}), **env_config.get('deployment', {})}
    env_vars = env_config.get('environment_variables', {})
    secrets = service_config.get('secrets', [])
    
    # Merge circuit_breaker config specifically
    base_circuit_breaker = service_config.get('scaling', {}).get('circuit_breaker', {})
    env_circuit_breaker = env_config.get('scaling', {}).get('circuit_breaker', {})
    circuit_breaker = {**base_circuit_breaker, **env_circuit_breaker}

    # Generate Terraform
    tf_content = f'''terraform {{
  backend "s3" {{
    bucket = "terraform-state-647272350116"
    key    = "{environment}/services/{name}/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }}
  
  required_providers {{
    aws = {{
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }}
    random = {{
      source  = "hashicorp/random"
      version = "~> 3.1"
    }}
  }}
}}

# Data sources
data "aws_caller_identity" "current" {{}}

# ECR Repository (use existing)
data "aws_ecr_repository" "{name.replace('-', '_')}_repo" {{
  name = "{name}-{environment}"
}}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "{name.replace('-', '_')}_lifecycle" {{
  repository = data.aws_ecr_repository.{name.replace('-', '_')}_repo.name

  policy = jsonencode({{
    rules = [
      {{
        rulePriority = 1
        description  = "Keep last 5 production images"
        selection = {{
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }}
        action = {{
          type = "expire"
        }}
      }},
      {{
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {{
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }}
        action = {{
          type = "expire"
        }}
      }}
    ]
  }})
}}

provider "aws" {{
  region = "us-east-1"
}}

# Data sources - read from existing infrastructure
data "terraform_remote_state" "core" {{
  backend = "s3"
  config = {{
    bucket = "terraform-state-647272350116"
    key    = "{environment}/core/terraform.tfstate"
    region = "us-east-1"
  }}
}}

# SQS Queue
resource "aws_sqs_queue" "{name.replace('-', '_')}_queue" {{
  name                      = "{environment}-{name}-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds = 1209600
  
  tags = {{
    Name        = "{environment}-{name}-queue"
    Environment = "{environment}"
    Service     = "{name}"
    Criticality = "critical"
  }}
}}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "{name.replace('-', '_')}_dlq" {{
  name = "{environment}-{name}-queue-dlq"
  
  tags = {{
    Name        = "{environment}-{name}-queue-dlq"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}

# SQS Queue Policy for EventBridge
resource "aws_sqs_queue_policy" "{name.replace('-', '_')}_queue_policy" {{
  queue_url = aws_sqs_queue.{name.replace('-', '_')}_queue.id

  policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [
      {{
        Effect = "Allow"
        Principal = {{
          Service = "events.amazonaws.com"
        }}
        Action = "sqs:SendMessage"
        Resource = aws_sqs_queue.{name.replace('-', '_')}_queue.arn
        Condition = {{
          StringEquals = {{
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }}
        }}
      }}
    ]
  }})
}}

# SQS Queue Policy
resource "aws_sqs_queue_redrive_policy" "{name.replace('-', '_')}_redrive" {{
  queue_url = aws_sqs_queue.{name.replace('-', '_')}_queue.id
  redrive_policy = jsonencode({{
    deadLetterTargetArn = aws_sqs_queue.{name.replace('-', '_')}_dlq.arn
    maxReceiveCount     = 3
  }})
}}

# ECS Task Definition
resource "aws_ecs_task_definition" "{name.replace('-', '_')}_task" {{
  family                   = "{environment}-{name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "{resources.get('cpu', 256)}"
  memory                   = "{resources.get('memory', 512)}"
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn           = aws_iam_role.task_role.arn
  skip_destroy             = true
  
  runtime_platform {{
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }}

  container_definitions = jsonencode([
    {{
      name  = "{name}"
      image = "647272350116.dkr.ecr.us-east-1.amazonaws.com/{name}-{environment}:v$(date +%Y%m%d_%H%M%S)_$(git rev-parse --short HEAD 2>/dev/null || echo 'local')"
      
      portMappings = [
        {{
          containerPort = 8080
          protocol      = "tcp"
        }}
      ]
      
      environment = ['''

    # Add environment variables from service.yaml
    for key, value in env_vars.items():
        tf_content += f'''
        {{ name = "{key}", value = "{value}" }},'''
    
    # Add required environment variables
    tf_content += f'''
        {{ name = "SERVICE_NAME", value = "{name}" }},
        {{ name = "ENVIRONMENT", value = "{environment}" }},
        {{ name = "PORT", value = "8080" }},
        {{ name = "SQS_QUEUE_URL", value = aws_sqs_queue.{name.replace('-', '_')}_queue.url }},
        # Application Signals
        {{ name = "_X_AMZN_TRACE_ID", value = "" }},
        {{ name = "OTEL_PROPAGATORS", value = "tracecontext,baggage,xray" }},
        {{ name = "OTEL_RESOURCE_ATTRIBUTES", value = "service.name={name},service.version=1.0,deployment.environment={environment}" }}
      ]'''

    # Add secrets if defined
    if secrets:
        tf_content += f'''
      
      secrets = ['''
        for secret in secrets:
            tf_content += f'''
        {{ 
          name      = "{secret}"
          valueFrom = "${{aws_secretsmanager_secret.{name.replace('-', '_')}_secrets.arn}}:{secret}::"
        }},'''
        tf_content += '''
      ]'''

    tf_content += f'''
      
      logConfiguration = {{
        logDriver = "awslogs"
        options = {{
          "awslogs-group"         = aws_cloudwatch_log_group.{name.replace('-', '_')}_logs.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }}
      }}
      
      # Application Signals service tags
      dockerLabels = {{
        "application-signals.service.name" = "{name}"
        "application-signals.environment" = "{environment}"
      }}
    }}
  ])
  
  tags = {{
    Name        = "{environment}-{name}"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}

# ECS Service - use existing cluster
resource "aws_ecs_service" "{name.replace('-', '_')}_service" {{
  name            = "{environment}-{name}"
  cluster         = data.terraform_remote_state.core.outputs.ecs_cluster_id
  task_definition = aws_ecs_task_definition.{name.replace('-', '_')}_task.arn
  desired_count   = {resources.get('desired_count', 1)}
  launch_type     = "FARGATE"
  
  deployment_maximum_percent         = {deployment.get('maximum_percent', 200)}
  deployment_minimum_healthy_percent = {deployment.get('minimum_healthy_percent', 100)}
  
  network_configuration {{
    subnets          = data.terraform_remote_state.core.outputs.private_subnet_ids
    security_groups  = [aws_security_group.{name.replace('-', '_')}_sg.id]
    assign_public_ip = false
  }}
  
  tags = {{
    Name        = "{environment}-{name}"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}

# Security Group
resource "aws_security_group" "{name.replace('-', '_')}_sg" {{
  name_prefix = "{environment}-{name}-"
  vpc_id      = data.terraform_remote_state.core.outputs.vpc_id
  
  ingress {{
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }}
  
  egress {{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }}
  
  tags = {{
    Name        = "{environment}-{name}-sg"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}

# IAM Roles
resource "aws_iam_role" "execution_role" {{
  name = "{environment}-{name}-execution-role"
  
  assume_role_policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [
      {{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {{
          Service = "ecs-tasks.amazonaws.com"
        }}
      }}
    ]
  }})
}}

resource "aws_iam_role_policy_attachment" "execution_role_policy" {{
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}}

# Secrets Manager Permissions for execution role
resource "aws_iam_role_policy" "execution_secrets_policy" {{
  name = "{environment}-{name}-execution-secrets-policy"
  role = aws_iam_role.execution_role.id
  
  policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [
      {{
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.{name.replace('-', '_')}_secrets.arn
        ]
      }}
    ]
  }})
}}

resource "aws_iam_role" "task_role" {{
  name = "{environment}-{name}-task-role"
  
  assume_role_policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [
      {{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {{
          Service = "ecs-tasks.amazonaws.com"
        }}
      }}
    ]
  }})
}}

# SQS Permissions
resource "aws_iam_role_policy" "sqs_policy" {{
  name = "{environment}-{name}-sqs-policy"
  role = aws_iam_role.task_role.id
  
  policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [
      {{
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          aws_sqs_queue.{name.replace('-', '_')}_queue.arn,
          aws_sqs_queue.{name.replace('-', '_')}_dlq.arn
        ]
      }}
    ]
  }})
}}

# Application Signals Permissions
resource "aws_iam_role_policy" "app_signals_policy" {{
  name = "{environment}-{name}-app-signals-policy"
  role = aws_iam_role.task_role.id

  policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [
      {{
        Effect = "Allow"
        Action = [
          "application-signals:*",
          "cloudwatch:PutMetricData",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      }}
    ]
  }})
}}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "{name.replace('-', '_')}_logs" {{
  name              = "/ecs/{environment}-{name}"
  retention_in_days = 7
  
  lifecycle {{
    ignore_changes = [retention_in_days]
  }}
  
  tags = {{
    Name        = "{environment}-{name}-logs"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}
'''

    # Add single Secrets Manager resource for all secrets
    if secrets:
        tf_content += f'''
# Random ID for unique secret naming
resource "random_id" "{name.replace('-', '_')}_secret_suffix" {{
  byte_length = 4
}}

# Secrets Manager Secret for service
resource "aws_secretsmanager_secret" "{name.replace('-', '_')}_secrets" {{
  name                    = "{environment}-{name}-secrets-${{random_id.{name.replace('-', '_')}_secret_suffix.hex}}"
  description             = "Secret for {environment}-{name}"
  recovery_window_in_days = 0
  
  tags = {{
    Name        = "{environment}-{name}-secrets"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}

resource "aws_secretsmanager_secret_version" "{name.replace('-', '_')}_secrets_version" {{
  secret_id     = aws_secretsmanager_secret.{name.replace('-', '_')}_secrets.id
  secret_string = jsonencode({{
    {", ".join([f'"{secret}": "changeme"' for secret in secrets])}
  }})
  
  lifecycle {{
    ignore_changes = [secret_string]
  }}
}}

# Secrets Manager Permissions
resource "aws_iam_role_policy" "secrets_policy" {{
  name = "{environment}-{name}-secrets-policy"
  role = aws_iam_role.task_role.id
  
  policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [
      {{
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.{name.replace('-', '_')}_secrets.arn
        ]
      }}
    ]
  }})
}}
'''

    # Auto Scaling Policies - Step Scaling
    tf_content += f'''
# Auto Scaling Target
resource "aws_appautoscaling_target" "{name.replace('-', '_')}_target" {{
  max_capacity       = {resources.get('max_count', 10)}
  min_capacity       = 1
  resource_id        = "service/${{data.terraform_remote_state.core.outputs.ecs_cluster_name}}/${{aws_ecs_service.{name.replace('-', '_')}_service.name}}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  
  tags = {{
    Name        = "{environment}-{name}-autoscaling-target"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}

# Scale Up Policy
resource "aws_appautoscaling_policy" "{name.replace('-', '_')}_scale_up_policy" {{
  name               = "{environment}-{name}-scale-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.{name.replace('-', '_')}_target.resource_id
  scalable_dimension = aws_appautoscaling_target.{name.replace('-', '_')}_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.{name.replace('-', '_')}_target.service_namespace

  step_scaling_policy_configuration {{
    adjustment_type         = "ChangeInCapacity"
    cooldown               = {int(scaling.get('metrics', [{}])[0].get('cooldown_up', '30s').rstrip('s')) if scaling.get('metrics') else int(scaling.get('scale_up_cooldown', '30s').rstrip('s'))}
    metric_aggregation_type = "Average"

    step_adjustment {{
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }}
  }}
}}

# Scale Down Policy
resource "aws_appautoscaling_policy" "{name.replace('-', '_')}_scale_down_policy" {{
  name               = "{environment}-{name}-scale-down"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.{name.replace('-', '_')}_target.resource_id
  scalable_dimension = aws_appautoscaling_target.{name.replace('-', '_')}_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.{name.replace('-', '_')}_target.service_namespace

  step_scaling_policy_configuration {{
    adjustment_type         = "ChangeInCapacity"
    cooldown               = {int(scaling.get('metrics', [{}])[0].get('cooldown_down', '300s').rstrip('s')) if scaling.get('metrics') else int(scaling.get('scale_down_cooldown', '300s').rstrip('s'))}
    metric_aggregation_type = "Average"

    step_adjustment {{
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }}
  }}
}}

# Scale Up Alarm
resource "aws_cloudwatch_metric_alarm" "{name.replace('-', '_')}_scale_up_alarm" {{
  alarm_name          = "{environment}-{name}-scale-up-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "10"
  statistic           = "Sum"
  threshold           = "{scaling.get('metrics', [{}])[0].get('target_value', 10) if scaling.get('metrics') else scaling.get('target_value', 10)}"
  alarm_description   = "Scale up when visible messages > threshold"

  dimensions = {{
    QueueName = aws_sqs_queue.{name.replace('-', '_')}_queue.name
  }}

  alarm_actions = [aws_appautoscaling_policy.{name.replace('-', '_')}_scale_up_policy.arn]
  
  tags = {{
    Name        = "{environment}-{name}-scale-up-alarm"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}

# Scale Down Alarm
resource "aws_cloudwatch_metric_alarm" "{name.replace('-', '_')}_scale_down_alarm" {{
  alarm_name          = "{environment}-{name}-scale-down-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "10"
  statistic           = "Sum"
  threshold           = "{int(scaling.get('metrics', [{}])[0].get('target_value', 10) if scaling.get('metrics') else scaling.get('target_value', 10)) // 2}"
  alarm_description   = "Scale down when visible messages <= threshold"

  dimensions = {{
    QueueName = aws_sqs_queue.{name.replace('-', '_')}_queue.name
  }}

  alarm_actions = [aws_appautoscaling_policy.{name.replace('-', '_')}_scale_down_policy.arn]
  
  tags = {{
    Name        = "{environment}-{name}-scale-down-alarm"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}'''

    # Add CPU scaling policy if configured
    cpu_metric = None
    memory_metric = None
    if scaling.get('metrics'):
        for metric in scaling.get('metrics', []):
            if metric.get('name') == 'cpu_utilization':
                cpu_metric = metric
            elif metric.get('name') == 'memory_utilization':
                memory_metric = metric

    if cpu_metric:
        tf_content += f'''

# CPU Utilization Scale Up Alarm
resource "aws_cloudwatch_metric_alarm" "{name.replace('-', '_')}_cpu_alarm" {{
  alarm_name          = "{environment}-{name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "{cpu_metric.get('target_value', 75)}"
  alarm_description   = "Scale up when CPU > threshold"

  dimensions = {{
    ServiceName = aws_ecs_service.{name.replace('-', '_')}_service.name
    ClusterName = data.terraform_remote_state.core.outputs.ecs_cluster_name
  }}

  alarm_actions = [aws_appautoscaling_policy.{name.replace('-', '_')}_scale_up_policy.arn]
  
  tags = {{
    Name        = "{environment}-{name}-cpu-alarm"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}'''

    if memory_metric:
        tf_content += f'''

# Memory Utilization Scale Up Alarm
resource "aws_cloudwatch_metric_alarm" "{name.replace('-', '_')}_memory_alarm" {{
  alarm_name          = "{environment}-{name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "{memory_metric.get('target_value', 85)}"
  alarm_description   = "Scale up when Memory > threshold"

  dimensions = {{
    ServiceName = aws_ecs_service.{name.replace('-', '_')}_service.name
    ClusterName = data.terraform_remote_state.core.outputs.ecs_cluster_name
  }}

  alarm_actions = [aws_appautoscaling_policy.{name.replace('-', '_')}_scale_up_policy.arn]
  
  tags = {{
    Name        = "{environment}-{name}-memory-alarm"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}'''

    # Add circuit breaker monitoring
    if circuit_breaker.get('enabled'):
        tf_content += f'''

# Circuit Breaker CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "{name.replace('-', '_')}_task_failure_alarm" {{
  alarm_name          = "{environment}-{name}-low-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningCount"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Circuit breaker: Service has no running tasks - possible failures"
  
  dimensions = {{
    ServiceName = aws_ecs_service.{name.replace('-', '_')}_service.name
    ClusterName = data.terraform_remote_state.core.outputs.ecs_cluster_name
  }}
  
  tags = {{
    Name        = "{environment}-{name}-circuit-breaker"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "{name.replace('-', '_')}_queue_depth_high" {{
  alarm_name          = "{environment}-{name}-queue-depth-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfMessages"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = "{scaling.get('target_value', 5) * 2}"
  alarm_description   = "This metric monitors SQS queue depth for {name}"
  alarm_actions       = []

  dimensions = {{
    QueueName = aws_sqs_queue.{name.replace('-', '_')}_queue.name
  }}
  
  tags = {{
    Name        = "{environment}-{name}-queue-depth-alarm"
    Environment = "{environment}"
    Service     = "{name}"
  }}
}}
'''

    # Add outputs section
    tf_content += f'''
# Outputs
output "queue_url" {{
  value = aws_sqs_queue.{name.replace('-', '_')}_queue.url
}}

output "queue_arn" {{
  value = aws_sqs_queue.{name.replace('-', '_')}_queue.arn
}}

output "service_name" {{
  value = aws_ecs_service.{name.replace('-', '_')}_service.name
}}

output "cluster_name" {{
  value = data.terraform_remote_state.core.outputs.ecs_cluster_name
}}

output "task_definition_arn" {{
  value = aws_ecs_task_definition.{name.replace('-', '_')}_task.arn
}}

output "autoscaling_target_arn" {{
  value = aws_appautoscaling_target.{name.replace('-', '_')}_target.arn
}}
'''

    # Write Terraform file
    terraform_dir = os.path.join(service_path, '.terraform')
    os.makedirs(terraform_dir, exist_ok=True)
    
    terraform_file = os.path.join(terraform_dir, 'main.tf')
    with open(terraform_file, 'w') as f:
        f.write(tf_content)
    
    print(f"Generated Terraform in {terraform_file}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 generate-worker-infra.py <service-path> <environment>")
        sys.exit(1)
    
    service_path = sys.argv[1]
    environment = sys.argv[2]
    
    generate_worker_terraform(service_path, environment)
