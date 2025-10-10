# =============================================================================
# Parameter Store Layer Variables - 공유 변수 시스템 적용
# =============================================================================
# 목적: shared-variables.tf에서 정의된 공통 변수를 사용하여 일관성 확보

# 공유 설정 (shared-variables.tf에서 전달)
variable "shared_config" {
  description = "공유 설정 정보 (shared-variables.tf에서 전달)"
  type = object({
    name_prefix = string
    environment = string
    aws_region  = string
    aws_profile = string
    common_name = string
    common_tags = map(string)
  })
}

# 상태 관리 설정 (shared-variables.tf에서 전달)
variable "state_config" {
  description = "Terraform 상태 관리 설정 (shared-variables.tf에서 전달)"
  type = object({
    bucket_name = string
    region      = string
    profile     = string
  })
}

# =============================================================================
# Parameter Store 레이어 특화 변수 (단순화)
# =============================================================================

# Parameter Store 기본 설정
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

# 기본 파라미터만 유지 (복잡한 설정 제거)
variable "enable_sql_logging" {
  description = "SQL 로깅 활성화 여부 (개발 환경용)"
  type        = bool
  default     = false
}