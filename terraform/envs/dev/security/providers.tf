terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket         = "petclinic-tfstate-team-jungsu-kopo"
    key            = "dev/hwigwon/security/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "petclinic-tf-locks"
    encrypt        = true
    profile        = "petclinic-hwigwon"  # 휘권이의 IAM 계정
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "petclinic-hwigwon"  # 휘권이의 IAM 계정

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
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket         = "petclinic-tfstate-team-jungsu-kopo"
    key            = "dev/yeonghyeon/network/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "petclinic-tf-locks"
    encrypt        = true
    profile        = "2501340070@office.kopo.ac.kr"  # 학교 계정
  }
}