# S3 Frontend Hosting Module Variables

variable "name_prefix" {
  description = "리소스 이름 접두사 (예: petclinic-dev)"
  type        = string
}

variable "environment" {
  description = "환경 레이블 (예: dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

# 버저닝 설정
variable "enable_versioning" {
  description = "S3 버킷 버저닝 활성화 여부"
  type        = bool
  default     = true
}

# 로깅 설정
variable "enable_access_logging" {
  description = "S3 액세스 로깅 활성화 여부"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간 (일)"
  type        = number
  default     = 30
}

# CORS 설정
variable "enable_cors" {
  description = "S3 버킷 CORS 활성화 여부"
  type        = bool
  default     = true
}

variable "cors_allowed_origins" {
  description = "CORS 허용 오리진 목록"
  type        = list(string)
  default     = ["*"]
}