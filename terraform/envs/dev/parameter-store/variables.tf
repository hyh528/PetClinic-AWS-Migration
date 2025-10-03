# Parameter Store 레이어 변수 - 단일 책임 원칙 적용

# 기본 설정
variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "petclinic-dev"
}

variable "environment" {
  description = "환경 레이블"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

# Terraform 상태 관리
variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일 S3 버킷 이름"
  type        = string
}

variable "network_state_profile" {
  description = "네트워크 레이어 상태 파일 접근용 AWS 프로필"
  type        = string
  default     = "petclinic-yeonghyeon"
}

variable "application_state_profile" {
  description = "애플리케이션 레이어 상태 파일 접근용 AWS 프로필"
  type        = string
  default     = "petclinic-seokgyeom"
}

# Parameter Store 전용 설정
variable "parameter_prefix" {
  description = "Parameter Store 파라미터 접두사"
  type        = string
  default     = "/petclinic"
}

variable "database_username" {
  description = "데이터베이스 사용자명"
  type        = string
  default     = "petclinic"
}

variable "enable_sql_logging" {
  description = "SQL 로깅 활성화 여부 (개발 환경용)"
  type        = bool
  default     = true
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

# 고급 설정
variable "parameter_tier" {
  description = "Parameter Store 티어"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Standard", "Advanced", "Intelligent-Tiering"], var.parameter_tier)
    error_message = "Parameter 티어는 Standard, Advanced, Intelligent-Tiering 중 하나여야 합니다."
  }
}

variable "allowed_pattern" {
  description = "파라미터 값에 대한 정규식 패턴"
  type        = string
  default     = ""
}

variable "data_type" {
  description = "파라미터 데이터 타입"
  type        = string
  default     = "text"
}

# 태그
variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default = {
    Project     = "petclinic"
    ManagedBy   = "terraform"
    Layer       = "parameter-store"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# Provider 설정
variable "aws_profile" {
  description = "사용할 AWS CLI 프로필"
  type        = string
  default     = "petclinic-seokgyeom"
}