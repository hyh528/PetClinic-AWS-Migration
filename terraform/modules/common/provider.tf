# =============================================================================
# Common Provider Configuration
# =============================================================================
# 목적: 모든 레이어에서 사용하는 공통 Provider 설정을 중앙화

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Default AWS Provider (Seoul Region)
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}

# Global services provider (us-east-1) - CloudFront, ACM 등
provider "aws" {
  alias   = "global"
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}

# Tokyo region provider (테스트용)
provider "aws" {
  alias   = "tokyo"
  region  = "ap-northeast-1"
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}