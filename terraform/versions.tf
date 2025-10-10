# =============================================================================
# Terraform 및 Provider 버전 제약
# =============================================================================
# 목적: Terraform 및 Provider 버전 호환성 보장

terraform {
  # Terraform 최소 버전 요구사항
  required_version = ">= 1.12.0"

  # Required Providers 및 버전 제약
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    
    # 추가 Provider (필요시 활성화)
    # random = {
    #   source  = "hashicorp/random"
    #   version = "~> 3.4"
    # }
    
    # null = {
    #   source  = "hashicorp/null"
    #   version = "~> 3.2"
    # }
    
    # local = {
    #   source  = "hashicorp/local"
    #   version = "~> 2.4"
    # }
  }

  # Backend 설정은 backend.hcl에서 관리
  # terraform init -backend-config=backend.hcl 로 초기화
}