# ==========================================
# AWS Native Services 레이어 변수 정의
# ==========================================
# 클린 코드 원칙: 의미 있는 이름과 명확한 설명

variable "environment" {
  description = "배포 환경 (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "petclinic"

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 50
    error_message = "프로젝트 이름은 1-50자 사이여야 합니다."
  }
}

variable "api_throttle_rate_limit" {
  description = "API Gateway 스로틀링 요청 제한 (req/sec)"
  type        = number
  default     = 1000

  validation {
    condition     = var.api_throttle_rate_limit > 0 && var.api_throttle_rate_limit <= 10000
    error_message = "API 스로틀링 제한은 1-10000 사이여야 합니다."
  }
}

variable "api_throttle_burst_limit" {
  description = "API Gateway 스로틀링 버스트 제한"
  type        = number
  default     = 2000

  validation {
    condition     = var.api_throttle_burst_limit >= var.api_throttle_rate_limit
    error_message = "버스트 제한은 요청 제한보다 크거나 같아야 합니다."
  }
}

variable "lambda_memory_size" {
  description = "Lambda 함수 메모리 크기 (MB)"
  type        = number
  default     = 512

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda 메모리는 128-10240MB 사이여야 합니다."
  }
}

variable "lambda_timeout" {
  description = "Lambda 함수 타임아웃 (초)"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout > 0 && var.lambda_timeout <= 900
    error_message = "Lambda 타임아웃은 1-900초 사이여야 합니다."
  }
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock 모델 ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"

  validation {
    condition     = length(var.bedrock_model_id) > 0
    error_message = "Bedrock 모델 ID는 비어있을 수 없습니다."
  }
}

variable "cloud_map_dns_ttl" {
  description = "Cloud Map DNS TTL (초)"
  type        = number
  default     = 60

  validation {
    condition     = var.cloud_map_dns_ttl >= 0 && var.cloud_map_dns_ttl <= 2147483647
    error_message = "DNS TTL은 0-2147483647초 사이여야 합니다."
  }
}

variable "additional_tags" {
  description = "추가 리소스 태그"
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.additional_tags) <= 50
    error_message = "추가 태그는 최대 50개까지 설정 가능합니다."
  }
}