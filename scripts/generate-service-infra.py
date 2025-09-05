#!/usr/bin/env python3
import yaml
import os
import sys

def generate_lambda_tf(service_config, environment):
    """Generate Terraform for Lambda API service using existing API Gateway from core"""
    name = service_config['name']
    
    # Get environment-specific config
    env_config = service_config.get('environments', {}).get(environment, {})
    base_resources = service_config.get('resources', {})
    env_resources = env_config.get('resources', {})
    
    # Merge resources
    memory = env_resources.get('memory', base_resources.get('memory', 512))
    timeout_str = str(env_resources.get('timeout', base_resources.get('timeout', '30s')))
    timeout = int(timeout_str.replace('s', ''))
    
    tf_content = f'''# Generated Terraform for {name}
terraform {{
  backend "s3" {{
    bucket = "terraform-state-647272350116"
    key    = "{environment}/services/{name}/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }}
}}

provider "aws" {{
  region = "us-east-1"
}}

# Data source from core infrastructure
data "terraform_remote_state" "core" {{
  backend = "s3"
  config = {{
    bucket = "terraform-state-647272350116"
    key    = "{environment}/core/terraform.tfstate"
    region = "us-east-1"
  }}
}}

# Lambda function with Web Adapter
resource "aws_lambda_function" "{name.replace('-', '_')}" {{
  function_name = "{environment}-{name}"
  role         = aws_iam_role.lambda_role.arn
  handler      = "bootstrap"
  runtime      = "provided.al2"
  filename     = "./{name}.zip"
  source_code_hash = filebase64sha256("./{name}.zip")
  description  = "Deployed on ${{formatdate("YYYY-MM-DD hh:mm:ss", timestamp())}}"
  
  memory_size  = {memory}
  timeout      = {timeout}
  architectures = ["{service_config.get('resources', {}).get('architecture', 'arm64')}"]
  
  # Web Adapter Layer
  layers = ["arn:aws:lambda:us-east-1:753240598075:layer:LambdaAdapterLayerArm64:25"]
  
  # Publish version for API Gateway integration
  publish = true
  
  environment {{
    variables = {{
'''
    
    # Add environment variables
    env_vars = env_config.get('environment_variables', {})
    for key, value in env_vars.items():
        tf_content += f'      {key} = "{value}"\n'
    
    tf_content += f'''      ENVIRONMENT = "{environment}"
      SERVICE_NAME = "{name}"
      PORT = "8080"
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/bootstrap"
      AWS_LWA_ASYNC_INIT = "true"
      AWS_LWA_READINESS_CHECK_PATH = "/health"
    }}
  }}
}}

# Lambda Alias for stage management
resource "aws_lambda_alias" "{name.replace('-', '_')}_alias" {{
  name             = "{service_config.get('stage', 'latest')}"
  description      = "Alias for {name} pointing to latest version"
  function_name    = aws_lambda_function.{name.replace('-', '_')}.function_name
  function_version = aws_lambda_function.{name.replace('-', '_')}.version
}}

# IAM role
resource "aws_iam_role" "lambda_role" {{
  name = "{environment}-{name}-lambda-role"
  assume_role_policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [{{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {{ Service = "lambda.amazonaws.com" }}
    }}]
  }})
}}

resource "aws_iam_role_policy_attachment" "lambda_basic" {{
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}}

'''
    
    # Generate API Gateway resources using existing API Gateway
    created_resources = {}  # Track created resources to avoid duplicates
    
    for i, route in enumerate(service_config.get('routing', [])):
        method = route.get('method', 'GET')
        path = route.get('path', '/').lstrip('/')
        
        if not path:
            continue
            
        # Split path into segments and create nested resources
        path_segments = path.split('/')
        parent_id = "data.terraform_remote_state.core.outputs.api_gateway_root_resource_id"
        current_path = ""
        
        for segment in path_segments:
            current_path = f"{current_path}/{segment}" if current_path else segment
            resource_name = f"{name}_{current_path}".replace('/', '_').replace('-', '_')
            
            # Only create resource if not already created
            if resource_name not in created_resources:
                tf_content += f'''# API Gateway Resource - /{current_path} for {name}
resource "aws_api_gateway_resource" "{resource_name}" {{
  rest_api_id = data.terraform_remote_state.core.outputs.api_gateway_id
  parent_id   = {parent_id}
  path_part   = "{segment}"
}}

'''
                created_resources[resource_name] = f"aws_api_gateway_resource.{resource_name}.id"
            
            parent_id = created_resources[resource_name]
        
        # Method and Integration for the final resource
        final_resource_name = f"{name}_{path}".replace('/', '_').replace('-', '_')
        method_name = f"{final_resource_name}_{method.lower()}"
        
        tf_content += f'''# {method} Method for /{path} -> {name}
resource "aws_api_gateway_method" "{method_name}" {{
  rest_api_id   = data.terraform_remote_state.core.outputs.api_gateway_id
  resource_id   = {parent_id}
  http_method   = "{method}"
  authorization = "NONE"
}}

resource "aws_api_gateway_integration" "{method_name}" {{
  rest_api_id = data.terraform_remote_state.core.outputs.api_gateway_id
  resource_id = {parent_id}
  http_method = aws_api_gateway_method.{method_name}.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_alias.{name.replace('-', '_')}_alias.invoke_arn
}}

'''
    
    # Lambda Permission for API Gateway
    tf_content += f'''# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {{
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_alias.{name.replace('-', '_')}_alias.function_name
  qualifier     = aws_lambda_alias.{name.replace('-', '_')}_alias.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${{data.terraform_remote_state.core.outputs.api_gateway_execution_arn}}/*/*"
}}

'''
    
    # Generate secrets from service.yaml
    secrets = service_config.get('secrets', [])
    if secrets:
        tf_content += f'''# Secrets Manager for {name}
'''
        for secret in secrets:
            secret_name = f"{environment}/{name}/{secret}"
            resource_name = f"{name}_{secret}".replace('-', '_')
            
            tf_content += f'''resource "aws_secretsmanager_secret" "{resource_name}" {{
  name = "{secret_name}"
  description = "Secret {secret} for {name} service in {environment}"
  
  tags = {{
    Service = "{name}"
    Environment = "{environment}"
  }}
}}

resource "aws_secretsmanager_secret_version" "{resource_name}_version" {{
  secret_id     = aws_secretsmanager_secret.{resource_name}.id
  secret_string = "n/a"
  
  lifecycle {{
    ignore_changes = [secret_string]
  }}
}}

'''
    
    # Lambda IAM policy for secrets access
    if secrets:
        tf_content += f'''# IAM policy for secrets access
resource "aws_iam_role_policy" "secrets_policy" {{
  name = "{environment}-{name}-secrets-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [
      {{
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
'''
        for secret in secrets:
            resource_name = f"{name}_{secret}".replace('-', '_')
            tf_content += f'          aws_secretsmanager_secret.{resource_name}.arn,\n'
        
        tf_content = tf_content.rstrip(',\n') + '\n'  # Remove last comma
        tf_content += '''        ]
      }
    ]
  })
}

'''

    # EventBridge permissions if events are configured
    if service_config.get('event_routing'):
        tf_content += f'''# IAM policy for EventBridge access
resource "aws_iam_role_policy" "eventbridge_policy" {{
  name = "{environment}-{name}-eventbridge-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({{
    Version = "2012-10-17"
    Statement = [
      {{
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = aws_cloudwatch_event_bus.{name.replace('-', '_')}_events.arn
      }}
    ]
  }})
}}

'''
    
    tf_content += f'''# Outputs
output "lambda_arn" {{
  value = aws_lambda_function.{name.replace('-', '_')}.arn
}}

output "api_gateway_url" {{
  value = data.terraform_remote_state.core.outputs.api_gateway_invoke_url
}}

output "api_gateway_stage" {{
  value = "{service_config.get('stage', 'latest')}"
}}
'''
    
    return tf_content

def generate_eventbridge_tf(service_config, environment):
    """Generate EventBridge resources with rules for each service"""
    name = service_config['name']
    
    tf_content = f'''
# EventBridge bus for {name}
resource "aws_cloudwatch_event_bus" "{name.replace('-', '_')}_events" {{
  name = "{environment}-{name}-events"
}}

'''
    
    # Generate EventBridge rules from event_routing in service.yaml
    for routing in service_config.get('event_routing', []):
        event_type = routing.get('event', '')  # Use 'event' not 'event_type'
        rule_name = f"{name}_{event_type}".replace('-', '_').replace('.', '_')
        
        tf_content += f'''# EventBridge rule for {event_type}
resource "aws_cloudwatch_event_rule" "{rule_name}" {{
  name           = "{environment}-{name}-{event_type}"
  event_bus_name = aws_cloudwatch_event_bus.{name.replace('-', '_')}_events.name
  
  event_pattern = jsonencode({{
    source      = ["{name}"]
    detail-type = ["{event_type}"]
  }})
}}

'''
        
        # Generate targets for each rule
        for i, target in enumerate(routing.get('targets', [])):
            target_name = f"{rule_name}_target_{i}"
            queue_name = target.get('queue', target)
            
            tf_content += f'''# EventBridge target to {queue_name}
resource "aws_cloudwatch_event_target" "{target_name}" {{
  rule           = aws_cloudwatch_event_rule.{rule_name}.name
  event_bus_name = aws_cloudwatch_event_bus.{name.replace('-', '_')}_events.name
  target_id      = "{queue_name}"
  arn            = "arn:aws:sqs:us-east-1:${{data.aws_caller_identity.current.account_id}}:{environment}-{queue_name}"
}}

'''
    
    # Add data source for account ID
    if service_config.get('event_routing'):
        tf_content += '''# Data source for account ID
data "aws_caller_identity" "current" {}

'''
    
    return tf_content

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 generate-service-infra.py <service-path> <environment>")
        sys.exit(1)
    
    service_path = sys.argv[1]
    environment = sys.argv[2]
    
    # Read service.yaml
    with open(f"{service_path}/service.yaml", 'r') as f:
        service_config = yaml.safe_load(f)
    
    service_name = service_config['name']
    
    # Create terraform directory in service/.terraform
    terraform_dir = f"{service_path}/.terraform"
    os.makedirs(terraform_dir, exist_ok=True)
    
    # Generate Terraform files
    lambda_tf = generate_lambda_tf(service_config, environment)
    eventbridge_tf = generate_eventbridge_tf(service_config, environment)
    
    # Write to service/.terraform directory
    with open(f"{terraform_dir}/main.tf", 'w') as f:
        f.write(lambda_tf)
        f.write(eventbridge_tf)
    
    print(f"Generated Terraform in {terraform_dir}/main.tf")

if __name__ == "__main__":
    main()
