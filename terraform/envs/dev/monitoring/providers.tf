# ==========================================
# Monitoring 레이어 프로바이더 설정
# ==========================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "petclinic-terraform-state-dev"
    key            = "monitoring/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "petclinic-terraform-locks"
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}