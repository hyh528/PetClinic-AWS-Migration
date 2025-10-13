# =============================================================================
# Database Layer Variables
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
# Database Layer 전용 변수
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
  description = "백업 시간대(UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "유지보수 시간대(UTC)"
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