# Lambda GenAI 모듈 변수 정의

# 기본 설정
variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "환경 이름 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default = {
    Project   = "petclinic"
    ManagedBy = "terraform"
  }
}

# Lambda 함수 설정
variable "runtime" {
  description = "Lambda 런타임"
  type        = string
  default     = "python3.11"
}

variable "timeout" {
  description = "Lambda 함수 타임아웃 (초)"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda 함수 메모리 크기 (MB)"
  type        = number
  default     = 512
}

variable "function_alias" {
  description = "Lambda 함수 별칭"
  type        = string
  default     = "live"
}

variable "log_level" {
  description = "로그 레벨"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보존 기간 (일)"
  type        = number
  default     = 14
}

# Bedrock 설정
variable "bedrock_model_id" {
  description = "사용할 Bedrock 모델 ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

# 환경 변수
variable "environment_variables" {
  description = "Lambda 함수 환경 변수"
  type        = map(string)
  default     = {}
}

# VPC 설정 (선택사항)
variable "enable_vpc_config" {
  description = "VPC 설정 활성화 여부"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "Lambda 함수가 사용할 서브넷 ID 목록"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Lambda 함수에 적용할 보안 그룹 ID 목록"
  type        = list(string)
  default     = []
}

# API Gateway 통합
variable "api_gateway_execution_arn" {
  description = "API Gateway 실행 ARN (Lambda 권한용)"
  type        = string
}

# 모니터링 설정
variable "enable_monitoring" {
  description = "CloudWatch 알람 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_xray_tracing" {
  description = "X-Ray 추적 활성화 여부"
  type        = bool
  default     = true
}

variable "error_threshold" {
  description = "에러 알람 임계값"
  type        = number
  default     = 5
}

variable "duration_threshold" {
  description = "실행 시간 알람 임계값 (밀리초)"
  type        = number
  default     = 25000
}

variable "concurrent_executions_threshold" {
  description = "동시 실행 수 알람 임계값"
  type        = number
  default     = 100
}

variable "alarm_actions" {
  description = "알람 발생 시 실행할 액션 ARN 목록"
  type        = list(string)
  default     = []
}

# 성능 최적화
variable "provisioned_concurrency_count" {
  description = "프로비저닝된 동시 실행 수 (Cold Start 최소화용)"
  type        = number
  default     = 0
}

variable "dead_letter_queue_arn" {
  description = "데드 레터 큐 ARN (선택사항)"
  type        = string
  default     = null
}