# ==========================================
# Bootstrap: Provider 설정 (Singapore 리전)
# ==========================================

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # 기본 태그들 (모든 리소스에 자동 적용)
  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = "bootstrap"
      ManagedBy   = "terraform"
      Region      = var.aws_region
    }
  }
}