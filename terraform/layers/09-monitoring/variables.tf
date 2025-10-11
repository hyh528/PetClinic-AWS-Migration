# =============================================================================
# Monitoring Layer Variables - 공유 변수 서비스 적용
# =============================================================================
# 목적: shared-variables.tf에서 정의된 공통 변수를 사용하여 중복 제거

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
# Monitoring Layer 전용 변수
# =============================================================================

variable "alert_email" {
  description = "알람 알림을 받을 이메일 주소"
  type        = string
  default     = "admin@petclinic.local"
}