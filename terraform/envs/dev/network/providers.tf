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
    key            = "dev/yeonghyeon/network/terraform.tfstate"
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
      Layer       = "network"
      ManagedBy   = "terraform"
      Owner       = "team-petclinic"
      CostCenter  = "training"
    }
  }
}