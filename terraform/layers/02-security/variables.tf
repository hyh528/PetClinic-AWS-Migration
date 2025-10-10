# =============================================================================
# Security Layer Variables - 공유 변수 시스템 적용
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
# Security Layer 특화 변수
# =============================================================================

variable "enable_vpc_flow_logs" {
  description = "VPC Flow Logs 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "CloudTrail 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_alb_integration" {
  description = "ALB 보안 그룹과의 통합 활성화 여부 (application 레이어 배포 후 true로 설정)"
  type        = bool
  default     = false
}

# VPC 엔드포인트는 Network 레이어에서 관리되므로 여기서는 제거

# =============================================================================
# Cross-Layer 참조 설정
# =============================================================================

variable "team_members" {
  description = "팀 멤버 목록 (IAM 사용자 생성용)"
  type        = list(string)
  default     = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
}

variable "enable_role_based_policies" {
  description = "역할 기반 세분화된 정책 활성화 (Phase 1: false, Phase 2: true)"
  type        = bool
  default     = false
}