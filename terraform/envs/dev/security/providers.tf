terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket         = var.tfstate_bucket_name
    key            = "dev/hwigwon/security/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.aws_profile # 변수화된 프로파일(backend.tfvars 또는 -var-file로 주입)
  }
}

provider "aws" {
  # 리전/프로파일을 변수로 노출하여 환경 간 일관성 및 재사용성 향상
  region  = var.aws_region
  profile = var.aws_profile # backend.tfvars 또는 -var-file로 오버라이드 가능

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = "dev"
      Layer       = "security"
      ManagedBy   = "terraform"
      Owner       = "team-petclinic"
      CostCenter  = "training"
    }
  }
}

# Network 레이어 원격 상태 참조 (VPC, 서브넷, 라우팅 테이블 등)
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