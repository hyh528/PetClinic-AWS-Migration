# Parameter Store 모듈 변수 정의

variable "name_prefix" {
  description = "리소스 이름 접두사 (예: petclinic-dev)"
  type        = string
}

variable "environment" {
  description = "환경 레이블 (예: dev, staging, prod)"
  type        = string
}

variable "parameter_prefix" {
  description = "Parameter Store 파라미터 접두사 (예: /petclinic)"
  type        = string
  default     = "/petclinic"
}

# 파라미터 설정
variable "common_parameters" {
  description = "모든 서비스가 공유하는 공통 파라미터"
  type        = map(string)
  default     = {}
}

variable "environment_parameters" {
  description = "환경별 파라미터"
  type        = map(string)
  default     = {}
}

variable "secure_parameters" {
  description = "보안 파라미터 (SecureString으로 암호화)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "service_specific_parameters" {
  description = "서비스별 특정 파라미터"
  type        = map(string)
  default     = {}
}

# 암호화 설정
variable "kms_key_id" {
  description = "SecureString 암호화용 KMS 키 ID"
  type        = string
  default     = "alias/aws/ssm"
}

variable "kms_key_arn" {
  description = "KMS 키 ARN (IAM 정책용)"
  type        = string
  default     = ""
}

# IAM 설정
variable "create_iam_policy" {
  description = "Parameter Store 접근용 IAM 정책 생성 여부"
  type        = bool
  default     = true
}

# 로깅 설정
variable "enable_access_logging" {
  description = "Parameter Store 접근 로깅 활성화 여부"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간 (일)"
  type        = number
  default     = 30
}

# 태그
variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

# 고급 설정
variable "parameter_tier" {
  description = "Parameter Store 티어 (Standard, Advanced, Intelligent-Tiering)"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Standard", "Advanced", "Intelligent-Tiering"], var.parameter_tier)
    error_message = "Parameter 티어는 Standard, Advanced, Intelligent-Tiering 중 하나여야 합니다."
  }
}

variable "allowed_pattern" {
  description = "파라미터 값에 대한 정규식 패턴 (선택사항)"
  type        = string
  default     = ""
}

variable "data_type" {
  description = "파라미터 데이터 타입"
  type        = string
  default     = "text"
  
  validation {
    condition     = contains(["text", "aws:ec2:image"], var.data_type)
    error_message = "데이터 타입은 text 또는 aws:ec2:image여야 합니다."
  }
}