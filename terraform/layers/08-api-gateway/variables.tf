# =============================================================================
# API Gateway Layer Variables - 공유 변수 서비스 적용
# =============================================================================
# 목적: shared-variables.tf에서 정의된 공통 변수를 사용하여 중복 제거

# 공유 설정 (shared-variables.tf에서 전달)
variable "shared_config" {
  description = "공유 설정 정보 (shared-variables.tf에서 전달)"
  type = object({
    name_prefix = string
    environment = string
    aws_region  = string
    aws_profile = string
    common_name = string
    common_tags = map(string)
  })
}

# 상태 관리 설정 (shared-variables.tf에서 전달)
variable "state_config" {
  description = "Terraform 상태 관리 설정 (shared-variables.tf에서 전달)"
  type = object({
    bucket_name = string
    region      = string
    profile     = string
  })
}

# =============================================================================
# API Gateway Layer 전용 변수
# =============================================================================

# API Gateway 전용 설정
variable "stage_name" {
  description = "API Gateway 스테이지 이름"
  type        = string
  default     = "v1"
}

variable "throttle_rate_limit" {
  description = "초당 요청 수 제한"
  type        = number
  default     = 1000
}

variable "throttle_burst_limit" {
  description = "버스트 요청 수 제한"
  type        = number
  default     = 2000
}

variable "integration_timeout_ms" {
  description = "ALB 통합 타임아웃 (밀리초)"
  type        = number
  default     = 29000
}

# Lambda 통합 설정
variable "enable_lambda_integration" {
  description = "Lambda 통합 활성화 여부 (GenAI 서비스용)"
  type        = bool
  default     = false
}

variable "lambda_function_invoke_arn" {
  description = "Lambda 함수 호출 ARN (Lambda 통합 시 필요)"
  type        = string
  default     = null
}

variable "lambda_integration_timeout_ms" {
  description = "Lambda 통합 타임아웃 (밀리초)"
  type        = number
  default     = 29000
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간 (일)"
  type        = number
  default     = 14
}

variable "enable_xray_tracing" {
  description = "X-Ray 추적 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_cors" {
  description = "CORS 지원 활성화 여부"
  type        = bool
  default     = true
}

variable "create_usage_plan" {
  description = "사용량 계획 생성 여부"
  type        = bool
  default     = false
}

# 모니터링 설정
variable "enable_monitoring" {
  description = "CloudWatch 알람 활성화 여부"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "CloudWatch 대시보드 생성 여부"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "알람 발생 시 실행할 액션 (SNS 토픽 ARN 등)"
  type        = list(string)
  default     = []
}

# 알람 임계값
variable "error_4xx_threshold" {
  description = "4XX 에러 알람 임계값"
  type        = number
  default     = 20
}

variable "error_5xx_threshold" {
  description = "5XX 에러 알람 임계값"
  type        = number
  default     = 10
}

variable "latency_threshold" {
  description = "지연시간 알람 임계값 (밀리초)"
  type        = number
  default     = 2000
}

variable "integration_latency_threshold" {
  description = "통합 지연시간 알람 임계값 (밀리초)"
  type        = number
  default     = 1500
}