# AWS Provider Configuration

# Default AWS Provider (ap-northeast-1)
provider "aws" {
  region = "ap-northeast-1"

  # AWS Profile 설정 (선택사항)
  # profile = var.aws_profile

  # Assume Role 설정 (선택사항)
  # assume_role {
  #   role_arn = var.assume_role_arn
  # }

  # Default tags for all resources
  default_tags {
    tags = {
      Project     = "PetClinic"
      ManagedBy   = "Terraform"
      Repository  = "petclinic-infrastructure"
    }
  }
}

# Additional provider for global services (us-east-1)
provider "aws" {
  alias  = "global"
  region = "us-east-1"

  # profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "PetClinic"
      ManagedBy = "Terraform"
      Repository = "petclinic-infrastructure"
    }
  }
}

# Provider for Tokyo region (if needed)
provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"

  # profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "PetClinic"
      ManagedBy = "Terraform"
      Repository = "petclinic-infrastructure"
    }
  }
}