# Parameter Store 레이어 프로바이더 설정

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# AWS 프로바이더 설정
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = var.environment
      ManagedBy   = "terraform"
      Layer       = "parameter-store"
      Owner       = "team-petclinic"
      CostCenter  = "training"
    }
  }
}