# =============================================================================
# AWS Native Services Layer Variables
# =============================================================================
# 목적: 레이어 전용 변수만 정의 (공통 변수는 common 모듈에서 상속)

# =============================================================================
# 공통 변수 (common 모듈에서 상속)
# =============================================================================

variable "name_prefix" {
  description = "모든 리소스 이름의 접두사"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
}

variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
}

# =============================================================================
# AWS Native Services Layer 전용 변수
# =============================================================================

# 통합 기능 제어 변수 (Feature Flags)
variable "enable_genai_integration" {
  description = "GenAI 서비스 통합 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "모니터링 활성화 여부"
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

variable "create_integration_dashboard" {
  description = "통합 대시보드 생성 여부"
  type        = bool
  default     = true
}

# API Gateway 통합 설정
variable "genai_integration_timeout_ms" {
  description = "GenAI 통합 타임아웃 (밀리초)"
  type        = number
  default     = 29000

  validation {
    condition     = var.genai_integration_timeout_ms >= 50 && var.genai_integration_timeout_ms <= 29000
    error_message = "타임아웃은 50ms에서 29000ms 사이여야 합니다."
  }
}

variable "require_api_key" {
  description = "API 키 요구 여부"
  type        = bool
  default     = false
}

# 모니터링 및 알람 설정
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

variable "alarm_actions" {
  description = "알람 액션 (SNS 토픽 ARN 목록)"
  type        = list(string)
  default     = []
}

# 보안 설정
variable "data_classification" {
  description = "데이터 분류 (public, internal, confidential, restricted)"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "데이터 분류는 public, internal, confidential, restricted 중 하나여야 합니다."
  }
}

variable "compliance_requirements" {
  description = "컴플라이언스 요구사항"
  type        = string
  default     = "none"
}

variable "waf_rate_limit" {
  description = "WAF 속도 제한 (5분당 요청 수)"
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 20000000
    error_message = "WAF 속도 제한은 100에서 20,000,000 사이여야 합니다."
  }
}

# 비용 최적화 설정
variable "auto_shutdown_enabled" {
  description = "자동 종료 활성화 여부 (개발 환경용)"
  type        = bool
  default     = true
}

variable "backup_required" {
  description = "백업 필요 여부"
  type        = bool
  default     = false
}

# 로깅 및 추적 설정
variable "log_retention_days" {
  description = "로그 보관 기간 (일)"
  type        = number
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "로그 보관 기간은 CloudWatch Logs에서 지원하는 값이어야 합니다."
  }
}

variable "enable_xray_tracing" {
  description = "X-Ray 추적 활성화 여부"
  type        = bool
  default     = true
}

variable "xray_tracing_mode" {
  description = "X-Ray 추적 모드 (Active 또는 PassThrough)"
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.xray_tracing_mode)
    error_message = "X-Ray 추적 모드는 Active 또는 PassThrough여야 합니다."
  }
}