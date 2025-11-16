# =============================================================================
# AWS Native Services Integration Module - Variables
# =============================================================================

# =============================================================================
# 기본 설정
# =============================================================================

variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix는 소문자, 숫자, 하이픈만 포함할 수 있습니다."
  }
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

# =============================================================================
# API Gateway 설정
# =============================================================================

variable "api_gateway_rest_api_id" {
  description = "API Gateway REST API ID"
  type        = string
}

variable "api_gateway_root_resource_id" {
  description = "API Gateway 루트 리소스 ID"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "API Gateway 실행 ARN"
  type        = string
}

variable "api_gateway_api_name" {
  description = "API Gateway API 이름"
  type        = string
}

variable "api_gateway_stage_name" {
  description = "API Gateway 스테이지 이름"
  type        = string
}

variable "api_gateway_domain_name" {
  description = "API Gateway 도메인 이름"
  type        = string
}

variable "api_gateway_stage_arn" {
  description = "API Gateway 스테이지 ARN"
  type        = string
}

# =============================================================================
# Lambda GenAI 설정
# =============================================================================

variable "lambda_genai_invoke_arn" {
  description = "Lambda GenAI 함수 호출 ARN"
  type        = string
}

variable "lambda_genai_function_name" {
  description = "Lambda GenAI 함수 이름"
  type        = string
}

# =============================================================================
# 기능 활성화 플래그
# =============================================================================

variable "enable_genai_integration" {
  description = "GenAI 통합 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "모니터링 활성화 여부"
  type        = bool
  default     = true
}

variable "create_integration_dashboard" {
  description = "통합 대시보드 생성 여부"
  type        = bool
  default     = true
}

variable "enable_health_checks" {
  description = "헬스체크 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_waf_protection" {
  description = "WAF 보호 활성화 여부"
  type        = bool
  default     = false
}

# =============================================================================
# 보안 설정
# =============================================================================

variable "require_api_key" {
  description = "API 키 요구 여부"
  type        = bool
  default     = false
}

# =============================================================================
# 성능 및 제한 설정
# =============================================================================

variable "genai_integration_timeout_ms" {
  description = "GenAI 통합 타임아웃 (밀리초)"
  type        = number
  default     = 29000

  validation {
    condition     = var.genai_integration_timeout_ms >= 1000 && var.genai_integration_timeout_ms <= 30000
    error_message = "타임아웃은 1000ms에서 30000ms 사이여야 합니다."
  }
}

variable "api_gateway_4xx_threshold" {
  description = "API Gateway 4xx 에러 임계값"
  type        = number
  default     = 10
}

variable "lambda_error_threshold" {
  description = "Lambda 에러 임계값"
  type        = number
  default     = 5
}

variable "waf_rate_limit" {
  description = "WAF 속도 제한 (요청/분)"
  type        = number
  default     = 1000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 10000
    error_message = "WAF 속도 제한은 100에서 10000 사이여야 합니다."
  }
}

# =============================================================================
# 알람 설정
# =============================================================================

variable "alarm_actions" {
  description = "알람 액션 (SNS 토픽 ARN 목록)"
  type        = list(string)
  default     = []
}