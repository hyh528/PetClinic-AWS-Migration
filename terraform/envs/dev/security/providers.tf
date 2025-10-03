terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # network 폴더와 버전을 맞추는 것이 안전합니다.
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
      Layer       = "security" # 이 디렉토리의 역할은 'security' 입니다.
      ManagedBy   = "terraform"
      Owner       = "team-petclinic"
      CostCenter  = "training"
    }
  }
}