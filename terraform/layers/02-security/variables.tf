# =============================================================================
# Security Layer Variables
# =============================================================================
# 목적: 레이어 전용 변수만 정의 (공통 변수는 shared/common.tfvars에서 로드)

# =============================================================================
# 공통 변수 (shared/common.tfvars에서 로드)
# =============================================================================

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "name_prefix" {
  description = "모든 리소스 이름의 접두사"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
}

variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
}

variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일을 저장하는 S3 버킷 이름"
  type        = string
}

# =============================================================================
# Security Layer 전용 변수
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
  description = "역할 기반 세분화된 정책 생성여부(Phase 1: false, Phase 2: true)"
  type        = bool
  default     = false
}