# =============================================================================
# Network Layer - Provider Configuration
# =============================================================================
# 목적: Network 레이어에서 사용할 AWS Provider 설정
# 베스트 프랙티스: 루트 모듈에서 provider 정의

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# AWS Provider (시드니 리전)
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "team-petclinic"
      CostCenter  = "training"
      Layer       = "01-network"
    }
  }
}