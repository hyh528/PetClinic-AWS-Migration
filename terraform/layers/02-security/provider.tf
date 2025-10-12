# =============================================================================
# AWS Provider Configuration
# =============================================================================
# 목적: AWS Provider 설정 및 자격 증명, 리전 정의
# 변수는 shared-variables.tf에서 정의됨

# Default AWS Provider (ap-northeast-2 Seoul)
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Assume Role 설정 (필요시 활성화)
  # assume_role {
  #   role_arn = var.assume_role_arn
  # }

  # 모든 리소스에 적용되는 기본 태그
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "PetClinic-AWS-Migration"
      Owner       = "AWS-Native-Migration-Team"
    }
  }
}

# Global services provider (us-east-1) - CloudFront, ACM 등
provider "aws" {
  alias   = "global"
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "PetClinic-AWS-Migration"
      Owner       = "AWS-Native-Migration-Team"
    }
  }
}

# Tokyo region provider (테스트용)
provider "aws" {
  alias   = "tokyo"
  region  = "ap-northeast-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "PetClinic-AWS-Migration"
      Owner       = "AWS-Native-Migration-Team"
    }
  }
}
