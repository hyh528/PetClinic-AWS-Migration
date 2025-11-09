# =============================================================================
# Backend Configuration - Shared across all layers (us-west-2 Oregon)
# =============================================================================
# Usage: terraform init -backend-config=../../backend.hcl -backend-config=backend.config
# 
# S3 native state locking enabled (no DynamoDB required)

bucket  = "petclinic-tfstate-oregon-dev"
region  = "us-west-2"
encrypt = true