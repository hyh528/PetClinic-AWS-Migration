# ==========================================
# Bootstrap: 버전/프로바이더 선언 (클린 아키텍처)
# - Terraform 및 AWS Provider 버전 고정
# - 다른 파일(variables/providers/main/outputs)로 역할 분리
# ==========================================

terraform {
  # 로컬 환경 TF 1.12.x 호환을 위해 하한을 1.12.0으로 지정
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}