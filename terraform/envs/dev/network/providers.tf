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
    key            = "dev/yeonghyeon/network/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "petclinic-tf-locks"
    encrypt        = true
    profile        = "2501340070@office.kopo.ac.kr"  # 학교 계정
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "2501340070@office.kopo.ac.kr"  # 예: petclinic-yeonghyeon

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = "dev"
      ManagedBy   = "terraform"
      Owner       = "team-petclinic"
      CostCenter  = "training"
    }
  }
}