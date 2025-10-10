terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  # 리전/프로파일을 변수로 노출하여 환경 간 일관성 및 재사용성 향상
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = "dev"
      Layer       = "application"
      ManagedBy   = "terraform"
      Owner       = "team-petclinic"
      CostCenter  = "training"
    }
  }
}


# Network 레이어 원격 상태 참조 (VPC/서브넷 등)
# - 버킷/리전/락테이블/암호화/프로파일을 변수로 표준화
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket         = var.tfstate_bucket_name
    key            = "dev/yeonghyeon/network/terraform.tfstate" # 팀별 경로 표준 유지
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.network_state_profile # Network 상태 접근 프로파일
  }
}


# Database 레이어 원격 상태 참조 (DB 연결 정보)
# - 표준화된 변수 사용으로 하드코딩 제거
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket         = var.tfstate_bucket_name
    key            = "dev/junje/database/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.database_state_profile # Database 상태 접근 프로파일
  }
}

# Security 레이어 원격 상태 참조 (보안 그룹 등)
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket         = var.tfstate_bucket_name
    key            = "dev/hwigwon/security/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.security_state_profile # Security 상태 접근 프로파일
  }
}