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