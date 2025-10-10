# ==========================================
# Terraform 및 Provider 설정
# ==========================================

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# ==========================================
# AWS Provider 설정 (메인 리전)
# ==========================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "petclinic"
      ManagedBy   = "terraform"
      Layer       = "state-management"
      Owner       = "devops-team"
    }
  }
}
