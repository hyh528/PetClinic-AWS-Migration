terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket         = var.tfstate_bucket_name
    key            = "dev/junje/database/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = "petclinic-junje"  # 준제의 IAM 계정
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "petclinic-junje"  # 준제의 IAM 계정

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = "dev"
      Layer       = "database"
      ManagedBy   = "terraform"
      Owner       = "team-petclinic"
      CostCenter  = "training"
    }
  }
}

# Network 레이어 상태 참조 (VPC, 서브넷 정보)
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket         = "petclinic-tfstate-team-jungsu-kopo"
    key            = "dev/yeonghyeon/network/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "petclinic-tf-locks"
    encrypt        = true
    profile        = "petclinic-yeonghyeon"  # Network 레이어 계정으로 상태 파일 접근
  }
}

# Security 레이어 상태 참조 (보안 그룹 정보)
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket         = "petclinic-tfstate-team-jungsu-kopo"
    key            = "dev/hwigwon/security/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "petclinic-tf-locks"
    encrypt        = true
    profile        = "petclinic-hwigwon"  # 휘권이의 IAM 계정
  }
}