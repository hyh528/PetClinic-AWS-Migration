# API Gateway 레이어 변수

# 공유 변수 사용 (shared-variables.tf에서 정의됨)
# 이 레이어에서는 레이어별 특화 변수만 정의

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

# 태그
variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default = {
    Project    = "petclinic"
    ManagedBy  = "terraform"
    Layer      = "api-gateway"
    Owner      = "team-petclinic"
    CostCenter = "training"
  }
}

# 상태 프로파일들은 공통 변수에서 관리됨
