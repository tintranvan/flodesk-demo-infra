#!/bin/bash

# Cleanup Core Infrastructure Script
# Usage: ./cleanup-core.sh [environment]

set -e

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/core"
ENV_FILE="$SCRIPT_DIR/../terraform/environments/${ENVIRONMENT}.tfvars"

echo "🧹 Cleaning up Flodesk Core Infrastructure"
echo "Environment: $ENVIRONMENT"

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Environment file not found: $ENV_FILE"
    exit 1
fi

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Initialize with environment-specific state key
echo "🔧 Initializing Terraform with environment-specific state..."
terraform init \
  -backend-config="key=${ENVIRONMENT}/core/terraform.tfstate" \
  -reconfigure

echo ""
echo "⚠️  WARNING: This will destroy ALL core infrastructure!"
echo "  - VPC and all subnets"
echo "  - ECS Cluster"
echo "  - API Gateway"
echo "  - EventBridge"
echo "  - ECR Repositories"
echo ""

read -p "🤔 Are you sure you want to destroy the $ENVIRONMENT environment? (type 'yes' to confirm): " -r
echo ""

if [[ $REPLY == "yes" ]]; then
    echo "🧹 Planning destruction..."
    terraform plan -destroy -var-file="$ENV_FILE" -out="destroy-plan-${ENVIRONMENT}"
    
    echo ""
    read -p "🔥 Final confirmation - destroy infrastructure? (type 'DESTROY' to confirm): " -r
    echo ""
    
    if [[ $REPLY == "DESTROY" ]]; then
        echo "🔥 Destroying infrastructure..."
        terraform apply "destroy-plan-${ENVIRONMENT}"
        
        echo ""
        echo "✅ Infrastructure destroyed successfully!"
        echo ""
        echo "📋 Cleanup completed for environment: $ENVIRONMENT"
        
        # Clean up plan files
        rm -f "destroy-plan-${ENVIRONMENT}"
        rm -f "tfplan-${ENVIRONMENT}"
        
    else
        echo "❌ Destruction cancelled"
        rm -f "destroy-plan-${ENVIRONMENT}"
        exit 1
    fi
else
    echo "❌ Cleanup cancelled"
    exit 1
fi
