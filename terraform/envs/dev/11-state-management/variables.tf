# ==========================================
# 개발 환경 상태 관리 변수
# ==========================================

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "환경 이름"
  type        = string
  default     = "dev"
}

# ==========================================
# S3 및 DynamoDB 설정
# ==========================================

variable "bucket_name" {
  description = "Terraform 상태 파일 S3 버킷 이름"
  type        = string
  default     = "petclinic-terraform-state-dev-ap-northeast-2"
}

variable "lock_table_name" {
  description = "Terraform 상태 잠금 DynamoDB 테이블 이름"
  type        = string
  default     = "petclinic-terraform-lock-dev"
}

# ==========================================
# 보안 설정
# ==========================================

variable "force_destroy" {
  description = "S3 버킷 강제 삭제 허용 (개발 환경에서만 true)"
  type        = bool
  default     = true  # 개발 환경에서는 true
}

variable "kms_key_deletion_window" {
  description = "KMS 키 삭제 대기 기간 (일)"
  type        = number
  default     = 7  # 개발 환경에서는 최소값
}

variable "versioning_status" {
  description = "S3 버킷 버전 관리 상태"
  type        = string
  default     = "Enabled"
}

# ==========================================
# 교차 리전 복제 설정
# ==========================================

variable "enable_cross_region_replication" {
  description = "교차 리전 복제 활성화 여부"
  type        = bool
  default     = false  # 개발 환경에서는 비용 절약을 위해 비활성화
}

variable "replica_region" {
  description = "복제본 저장 리전"
  type        = string
  default     = "ap-northeast-1"
}

# ==========================================
# 비용 최적화 설정
# ==========================================

variable "lifecycle_rules" {
  description = "S3 라이프사이클 규칙"
  type = object({
    transition_to_ia_days      = number
    transition_to_glacier_days = number
    expiration_days           = number
  })
  default = {
    transition_to_ia_days      = 30   # 30일 후 IA로 전환
    transition_to_glacier_days = 90   # 90일 후 Glacier로 전환
    expiration_days           = 180   # 개발 환경에서는 6개월 후 삭제
  }
}

variable "point_in_time_recovery" {
  description = "DynamoDB Point-in-Time Recovery 활성화"
  type        = bool
  default     = true
}

# ==========================================
# 모니터링 설정
# ==========================================

variable "enable_cloudtrail_logging" {
  description = "CloudTrail 로깅 활성화"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "알림 이메일 주소"
  type        = string
  default     = ""
}

# ==========================================
# 태그 설정
# ==========================================

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default = {
    Project     = "petclinic"
    Environment = "dev"
    ManagedBy   = "terraform"
    Component   = "state-management"
    Owner       = "devops-team"
    CostCenter  = "development"
  }
}