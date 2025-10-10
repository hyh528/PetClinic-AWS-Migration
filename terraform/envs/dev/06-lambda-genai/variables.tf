# Lambda GenAI 레이어 변수 정의

# 기본 설정
variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "환경 이름"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
  default     = "default"
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default = {
    Project     = "petclinic"
    Environment = "dev"
    ManagedBy   = "terraform"
    Layer       = "lambda-genai"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# Lambda 함수 설정
variable "lambda_runtime" {
  description = "Lambda 런타임"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda 함수 타임아웃 (초)"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda 함수 메모리 크기 (MB)"
  type        = number
  default     = 512
}

variable "log_level" {
  description = "로그 레벨"
  type        = string
  default     = "INFO"
}

# Bedrock 설정
variable "bedrock_model_id" {
  description = "사용할 Bedrock 모델 ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
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

# 알람 임계값
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
  default     = 50
}

# 성능 최적화
variable "provisioned_concurrency_count" {
  description = "프로비저닝된 동시 실행 수 (개발 환경에서는 0)"
  type        = number
  default     = 0
}

# 환경 변수
variable "environment_variables" {
  description = "Lambda 함수 추가 환경 변수"
  type        = map(string)
  default = {
    ENVIRONMENT = "dev"
    SERVICE_NAME = "genai"
  }
}

# Terraform 상태 관리
variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일 S3 버킷 이름"
  type        = string
  default     = "petclinic-terraform-state-dev"
}

variable "tf_lock_table_name" {
  description = "Terraform 상태 잠금 DynamoDB 테이블 이름"
  type        = string
  default     = "petclinic-terraform-lock"
}

variable "encrypt_state" {
  description = "Terraform 상태 파일 암호화 여부"
  type        = bool
  default     = true
}

# 원격 상태 접근 프로파일
variable "api_gateway_state_profile" {
  description = "API Gateway 상태 접근용 AWS 프로파일"
  type        = string
  default     = "default"
}