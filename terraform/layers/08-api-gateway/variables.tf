# =============================================================================
# API Gateway Layer Variables
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

# =============================================================================
# Remote State 참조를 위한 변수
# =============================================================================

variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일을 저장할 S3 버킷 이름"
  type        = string
}