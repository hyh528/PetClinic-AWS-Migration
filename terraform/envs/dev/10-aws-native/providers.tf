# ==========================================
# AWS Native Services 레이어 프로바이더 설정
# ==========================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }


}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = "dev"
      ManagedBy   = "terraform"
      Layer       = "aws-native"
    }
  }
}