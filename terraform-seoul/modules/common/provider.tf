# =============================================================================
# Common Provider Requirements (베스트 프랙티스)
# =============================================================================
# 목적: Provider 요구사항만 선언, 실제 provider는 루트 모듈에서 정의

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}