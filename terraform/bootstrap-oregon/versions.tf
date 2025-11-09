# ==========================================
# Bootstrap: 버전/프로바이더 선언 (클린 아키텍처)
# - Terraform 및 AWS Provider 버전 고정
# - 다른 파일(variables/providers/main/outputs)로 역할 분리
# ==========================================

terraform {
  # S3 네이티브 잠금 기능 (Terraform 1.10.0+) 호환
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}