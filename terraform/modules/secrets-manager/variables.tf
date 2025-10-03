# Secrets Manager 시크릿 이름 변수 정의
variable "secret_name" {
  description = "The name of the Secrets Manager secret."
  type        = string
}

# Secrets Manager 시크릿 설명 변수 정의
variable "secret_description" {
  description = "The description of the Secrets Manager secret."
  type        = string
  default     = "Managed by Terraform"
}

# Secrets Manager 시크릿 복구 기간 변수 정의
variable "recovery_window_in_days" {
  description = "The number of days that Secrets Manager waits before permanently deleting a secret."
  type        = number
  default     = 30
}

# Secrets Manager 시크릿 초기 값 변수 정의
variable "secret_string_initial_value" {
  description = "The initial value of the secret. Do NOT put sensitive data directly here. Use a placeholder or leave empty."
  type        = string
  default     = "" # 초기 값은 비워두거나 플레이스홀더를 사용합니다.
}

# 프로젝트 이름 변수 정의
variable "project_name" {
  description = "The name of the project, used for tagging resources."
  type        = string
}

# 환경 변수 정의
variable "environment" {
  description = "The environment name (e.g., dev, prod), used for tagging resources."
  type        = string
}
