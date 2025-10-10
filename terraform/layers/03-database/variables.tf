# =============================================================================
# Database Layer Variables - 공유 변수 시스템 적용
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
# Database Layer 특화 변수
# =============================================================================

# Aurora 클러스터 설정
variable "instance_class" {
  description = "Aurora 클러스터 인스턴스 클래스"
  type        = string
  default     = "db.serverless"
}

variable "engine_version" {
  description = "Aurora MySQL 엔진 버전"
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
}

# 데이터베이스 설정
variable "db_name" {
  description = "기본 데이터베이스 이름"
  type        = string
  default     = "petclinic"
}

variable "db_username" {
  description = "데이터베이스 마스터 사용자 이름"
  type        = string
  default     = "petclinic"
}

variable "db_port" {
  description = "데이터베이스 포트"
  type        = number
  default     = 3306
}

# 백업 및 유지보수 설정
variable "backup_retention_period" {
  description = "백업 보존 기간 (일)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "백업 윈도우 (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "유지보수 윈도우 (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# 보안 설정
variable "storage_encrypted" {
  description = "스토리지 암호화 활성화"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS 키 ID (기본값: AWS 관리형 키)"
  type        = string
  default     = null
}

# 성능 모니터링 설정
variable "performance_insights_enabled" {
  description = "Performance Insights 활성화"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring 간격 (초)"
  type        = number
  default     = 60
}

# AWS 관리형 비밀번호 설정
variable "manage_master_user_password" {
  description = "AWS 관리형 마스터 사용자 비밀번호 사용 (자동 생성 및 로테이션)"
  type        = bool
  default     = true
}