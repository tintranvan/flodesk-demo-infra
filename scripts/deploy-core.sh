#!/bin/bash

# Deploy Core Infrastructure Script
# Usage: ./deploy-core.sh [environment]

set -e

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/core"
ENV_FILE="$SCRIPT_DIR/../terraform/environments/${ENVIRONMENT}.tfvars"

echo "🚀 Deploying Flodesk Core Infrastructure"
echo "Environment: $ENVIRONMENT"
echo "Terraform Dir: $TERRAFORM_DIR"
echo "Environment File: $ENV_FILE"

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Environment file not found: $ENV_FILE"
    echo "Available environments:"
    ls -1 "$SCRIPT_DIR/../terraform/environments/" | sed 's/.tfvars$//' | sed 's/^/  - /'
    exit 1
fi

# Change to terraform directory
cd "$TERRAFORM_DIR"

echo ""
echo "📋 Terraform Configuration:"
echo "  - Backend: S3 (terraform-state-647272350116)"
echo "  - Profile: ${AWS_PROFILE:-default}"
echo "  - Region: us-east-1"
echo ""

# Initialize Terraform with environment-specific state key
echo "🔧 Initializing Terraform with environment-specific state..."
terraform init \
  -backend-config="key=${ENVIRONMENT}/core/terraform.tfstate" \
  -reconfigure

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📊 Planning deployment..."
terraform plan -var-file="$ENV_FILE" -out="tfplan-${ENVIRONMENT}"

# Ask for confirmation
echo ""
read -p "🤔 Do you want to apply this plan? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Applying Terraform plan..."
    terraform apply "tfplan-${ENVIRONMENT}"
    
    echo ""
    echo "✅ Core infrastructure deployed successfully!"
    echo ""
    echo "📋 Important outputs:"
    terraform output
    
    echo ""
    echo "🔑 API Gateway API Key (sensitive):"
    terraform output -raw api_gateway_api_key
    
    echo ""
    echo "🎉 Deployment completed!"
    echo ""
    echo "Next steps:"
    echo "  1. Note down the API Gateway URL and API Key"
    echo "  2. Deploy services using the service modules"
    echo "  3. Configure monitoring dashboards"
    
else
    echo "❌ Deployment cancelled"
    rm -f "tfplan-${ENVIRONMENT}"
    exit 1
fi
