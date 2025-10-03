# Lambda GenAI 레이어 프로바이더 설정

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
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
      Layer       = "lambda-genai"
      Owner       = "team-petclinic"
      CostCenter  = "training"
    }
  }
}

# API Gateway 레이어 원격 상태 참조
data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket         = var.tfstate_bucket_name
    key            = "dev/api-gateway/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.api_gateway_state_profile
  }
}