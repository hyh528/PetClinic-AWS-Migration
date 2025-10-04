# ==========================================
# Terraform 상태 관리 모듈 변수
# ==========================================

variable "environment" {
  description = "환경 이름 (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "bucket_name" {
  description = "Terraform 상태 파일을 저장할 S3 버킷 이름"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be lowercase, alphanumeric, and hyphens only."
  }
}

variable "lock_table_name" {
  description = "Terraform 상태 잠금을 위한 DynamoDB 테이블 이름"
  type        = string
  default     = "terraform-state-lock"
}

variable "force_destroy" {
  description = "S3 버킷을 강제로 삭제할지 여부 (개발 환경에서만 true)"
  type        = bool
  default     = false
}

variable "enable_cross_region_replication" {
  description = "교차 리전 복제 활성화 여부 (재해 복구용)"
  type        = bool
  default     = false
}

variable "replica_region" {
  description = "복제본을 저장할 AWS 리전"
  type        = string
  default     = "ap-northeast-1"
}

variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default = {
    Project     = "petclinic"
    ManagedBy   = "terraform"
    Component   = "state-management"
  }
}

# ==========================================
# 보안 및 컴플라이언스 설정
# ==========================================

variable "enable_mfa_delete" {
  description = "S3 버킷에서 MFA 삭제 활성화 여부"
  type        = bool
  default     = false
}

variable "kms_key_deletion_window" {
  description = "KMS 키 삭제 대기 기간 (일)"
  type        = number
  default     = 7
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

variable "versioning_status" {
  description = "S3 버킷 버전 관리 상태"
  type        = string
  default     = "Enabled"
  validation {
    condition     = contains(["Enabled", "Suspended"], var.versioning_status)
    error_message = "Versioning status must be either 'Enabled' or 'Suspended'."
  }
}

# ==========================================
# 비용 최적화 설정
# ==========================================

variable "lifecycle_rules" {
  description = "S3 라이프사이클 규칙 설정"
  type = object({
    transition_to_ia_days      = number
    transition_to_glacier_days = number
    expiration_days           = number
  })
  default = {
    transition_to_ia_days      = 30
    transition_to_glacier_days = 90
    expiration_days           = 365
  }
}

variable "point_in_time_recovery" {
  description = "DynamoDB Point-in-Time Recovery 활성화 여부"
  type        = bool
  default     = true
}

# ==========================================
# 모니터링 및 알림 설정
# ==========================================

variable "enable_cloudtrail_logging" {
  description = "S3 버킷에 대한 CloudTrail 로깅 활성화 여부"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "상태 파일 변경 알림을 받을 이메일 주소"
  type        = string
  default     = ""
}