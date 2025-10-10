# API Gateway 모듈 변수 정의

variable "name_prefix" {
  description = "리소스 이름 접두사 (예: petclinic-dev)"
  type        = string
}

variable "environment" {
  description = "환경 레이블 (예: dev, staging, prod)"
  type        = string
}

variable "stage_name" {
  description = "API Gateway 스테이지 이름"
  type        = string
  default     = "v1"
}

variable "alb_dns_name" {
  description = "통합할 ALB의 DNS 이름"
  type        = string
}

# Lambda 통합 설정
variable "enable_lambda_integration" {
  description = "Lambda 통합 활성화 여부"
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

  validation {
    condition     = var.lambda_integration_timeout_ms >= 50 && var.lambda_integration_timeout_ms <= 29000
    error_message = "Lambda 통합 타임아웃은 50ms에서 29000ms 사이여야 합니다."
  }
}

# 스로틀링 설정
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

# 통합 설정
variable "integration_timeout_ms" {
  description = "ALB 통합 타임아웃 (밀리초)"
  type        = number
  default     = 29000

  validation {
    condition     = var.integration_timeout_ms >= 50 && var.integration_timeout_ms <= 29000
    error_message = "통합 타임아웃은 50ms에서 29000ms 사이여야 합니다."
  }
}

# 로깅 설정
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

# CORS 설정
variable "enable_cors" {
  description = "CORS 지원 활성화 여부"
  type        = bool
  default     = true
}

# 사용량 계획 설정
variable "create_usage_plan" {
  description = "API 사용량 계획 생성 여부"
  type        = bool
  default     = false
}

variable "quota_limit" {
  description = "API 할당량 제한 (사용량 계획 활성화 시)"
  type        = number
  default     = 10000
}

variable "quota_period" {
  description = "API 할당량 기간 (DAY, WEEK, MONTH)"
  type        = string
  default     = "DAY"

  validation {
    condition     = contains(["DAY", "WEEK", "MONTH"], var.quota_period)
    error_message = "할당량 기간은 DAY, WEEK, MONTH 중 하나여야 합니다."
  }
}

# 태그
variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

# 고급 설정
variable "minimum_compression_size" {
  description = "응답 압축을 위한 최소 크기 (바이트)"
  type        = number
  default     = 1024

  validation {
    condition     = var.minimum_compression_size >= 0 && var.minimum_compression_size <= 10485760
    error_message = "압축 크기는 0에서 10MB(10485760 바이트) 사이여야 합니다."
  }
}

variable "api_key_source" {
  description = "API 키 소스 (HEADER, AUTHORIZER)"
  type        = string
  default     = "HEADER"

  validation {
    condition     = contains(["HEADER", "AUTHORIZER"], var.api_key_source)
    error_message = "API 키 소스는 HEADER 또는 AUTHORIZER여야 합니다."
  }
}

# 보안 설정
variable "disable_execute_api_endpoint" {
  description = "기본 execute-api 엔드포인트 비활성화 여부"
  type        = bool
  default     = false
}

variable "policy" {
  description = "API Gateway 리소스 정책 (JSON 문자열)"
  type        = string
  default     = null
}

# 서비스 설정 (확장 가능한 구조)
variable "custom_services" {
  description = "추가 사용자 정의 서비스 설정"
  type = map(object({
    path        = string
    parent_path = string
    description = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.custom_services :
      contains(["api", "root"], v.parent_path)
    ])
    error_message = "parent_path는 'api' 또는 'root'여야 합니다."
  }
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
  description = "4XX 에러 알람 임계값 (5분간 총 에러 수)"
  type        = number
  default     = 10
}

variable "error_5xx_threshold" {
  description = "5XX 에러 알람 임계값 (5분간 총 에러 수)"
  type        = number
  default     = 5
}

variable "latency_threshold" {
  description = "지연시간 알람 임계값 (밀리초)"
  type        = number
  default     = 1000
}

variable "integration_latency_threshold" {
  description = "통합 지연시간 알람 임계값 (밀리초)"
  type        = number
  default     = 800
}