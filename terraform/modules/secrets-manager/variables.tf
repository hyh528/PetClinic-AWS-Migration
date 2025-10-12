# Secrets Manager 시크릿 이름 변수
variable "secret_name" {
  description = "Secrets Manager 시크릿의 이름입니다."
  type        = string
}

# Secrets Manager 시크릿 설명 변수
variable "secret_description" {
  description = "Secrets Manager 시크릿의 설명입니다."
  type        = string
  default     = "Terraform으로 관리되는 시크릿"
}

# 시크릿 복구 기간 변수
variable "recovery_window_in_days" {
  description = "시크릿 삭제 후 복구 가능한 기간(일)입니다. 0으로 설정하면 즉시 삭제됩니다."
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days >= 0 && var.recovery_window_in_days <= 30
    error_message = "복구 기간은 0-30일 사이여야 합니다."
  }
}

# KMS 암호화 키 ID 변수
variable "kms_key_id" {
  description = "시크릿 암호화에 사용할 KMS 키 ID입니다. null이면 기본 키를 사용합니다."
  type        = string
  default     = null
}



# 초기 버전 생성 여부 변수
variable "create_initial_version" {
  description = "초기 시크릿 버전을 생성할지 여부입니다."
  type        = bool
  default     = false
}

# 시크릿 초기값 변수
variable "secret_string_value" {
  description = "시크릿의 초기값입니다. 민감 정보는 직접 입력하지 마세요!"
  type        = string
  default     = "placeholder-value"
  sensitive   = true
}

# 프로젝트 이름 변수
variable "project_name" {
  description = "리소스 태그에 사용될 프로젝트 이름입니다."
  type        = string
}

# 환경 변수
variable "environment" {
  description = "리소스 태그에 사용될 환경 이름입니다 (예: dev, prod)."
  type        = string
}
