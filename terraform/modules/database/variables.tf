# Database 모듈 변수들 (강화된 검증)

variable "name_prefix" {
  description = "리소스 이름 접두사, e.g., petclinic-dev"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.name_prefix)) && length(var.name_prefix) >= 3 && length(var.name_prefix) <= 63
    error_message = "name_prefix는 3-63자의 소문자, 숫자, 하이픈만 사용 가능하며, 하이픈으로 시작하거나 끝날 수 없습니다."
  }
}

variable "private_db_subnet_ids" {
  description = "DB 서브넷 그룹에 사용할 프라이빗 DB 서브넷 ID 목록"
  type        = list(string)

  validation {
    condition     = length(var.private_db_subnet_ids) >= 2
    error_message = "고가용성을 위해 최소 2개의 서브넷이 필요합니다."
  }

  validation {
    condition = alltrue([
      for subnet_id in var.private_db_subnet_ids : can(regex("^subnet-[a-f0-9]{8,17}$", subnet_id))
    ])
    error_message = "모든 서브넷 ID는 유효한 AWS 서브넷 ID 형식이어야 합니다 (subnet-xxxxxxxx)."
  }

  validation {
    condition     = length(var.private_db_subnet_ids) == length(distinct(var.private_db_subnet_ids))
    error_message = "서브넷 ID 목록에 중복된 값이 있습니다."
  }
}

variable "vpc_security_group_ids" {
  description = "RDS에 적용할 보안 그룹 ID 목록"
  type        = list(string)

  validation {
    condition     = length(var.vpc_security_group_ids) >= 1 && length(var.vpc_security_group_ids) <= 5
    error_message = "보안 그룹은 최소 1개, 최대 5개까지 지정할 수 있습니다."
  }

  validation {
    condition = alltrue([
      for sg_id in var.vpc_security_group_ids : can(regex("^sg-[a-f0-9]{8,17}$", sg_id))
    ])
    error_message = "모든 보안 그룹 ID는 유효한 AWS 보안 그룹 ID 형식이어야 합니다 (sg-xxxxxxxx)."
  }
}

variable "engine_version" {
  description = "Aurora MySQL 엔진 버전"
  type        = string
  default     = "8.0.mysql_aurora.3.07.0"
}

variable "instance_class" {
  description = "Aurora 인스턴스 클래스"
  type        = string
  default     = "db.serverless"
}

variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
  default     = "petclinic"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name)) && length(var.db_name) >= 1 && length(var.db_name) <= 64
    error_message = "데이터베이스 이름은 1-64자의 영문자로 시작하고, 영문자, 숫자, 밑줄만 포함할 수 있습니다."
  }
}

variable "db_username" {
  description = "데이터베이스 사용자 이름"
  type        = string
  default     = "petclinic"
}

variable "db_port" {
  description = "데이터베이스 포트"
  type        = number
  default     = 3306

  validation {
    condition     = var.db_port >= 1024 && var.db_port <= 65535
    error_message = "데이터베이스 포트는 1024-65535 범위여야 합니다."
  }

  validation {
    condition = !contains([
      22, 23, 53, 80, 135, 139, 443, 445, 993, 995, 1433, 1521, 3389, 5432, 5984
    ], var.db_port)
    error_message = "시스템 예약 포트나 다른 서비스에서 일반적으로 사용하는 포트는 피해주세요."
  }
}

variable "backup_retention_period" {
  description = "백업 보존 기간 (일)"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "백업 보존 기간은 1-35일 사이여야 합니다."
  }
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.tags : can(regex("^[a-zA-Z0-9+\\-=._:/@\\s]+$", k)) && can(regex("^[a-zA-Z0-9+\\-=._:/@\\s]*$", v))
    ])
    error_message = "태그 키와 값은 AWS 태그 명명 규칙을 준수해야 합니다."
  }
}

# 추가 보안 및 성능 변수들
variable "environment" {
  description = "환경 레이블 (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "development", "stg", "staging", "prd", "prod", "production", "test"], var.environment)
    error_message = "environment는 다음 중 하나여야 합니다: dev, development, stg, staging, prd, prod, production, test"
  }
}

variable "deletion_protection" {
  description = "삭제 보호 활성화 (프로덕션 환경 권장)"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "최종 스냅샷 생성 건너뛰기 (개발 환경에서만 true 권장)"
  type        = bool
  default     = false
}

variable "backup_window" {
  description = "백업 시간 윈도우 (UTC, HH:MM-HH:MM 형식)"
  type        = string
  default     = "03:00-04:00"

  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]-([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.backup_window))
    error_message = "백업 윈도우는 HH:MM-HH:MM 형식이어야 합니다 (예: 03:00-04:00)."
  }
}

variable "maintenance_window" {
  description = "유지보수 시간 윈도우 (UTC, ddd:HH:MM-ddd:HH:MM 형식)"
  type        = string
  default     = "sun:04:00-sun:05:00"

  validation {
    condition     = can(regex("^(mon|tue|wed|thu|fri|sat|sun):([0-1][0-9]|2[0-3]):[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window))
    error_message = "유지보수 윈도우는 ddd:HH:MM-ddd:HH:MM 형식이어야 합니다 (예: sun:04:00-sun:05:00)."
  }
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring 간격 (초, 0은 비활성화)"
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "모니터링 간격은 0, 1, 5, 10, 15, 30, 60 중 하나여야 합니다."
  }
}

variable "performance_insights_enabled" {
  description = "Performance Insights 활성화"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights 데이터 보존 기간 (일)"
  type        = number
  default     = 7

  validation {
    condition     = contains([7, 731], var.performance_insights_retention_period)
    error_message = "Performance Insights 보존 기간은 7일 또는 731일(2년)이어야 합니다."
  }
}

variable "auto_minor_version_upgrade" {
  description = "자동 마이너 버전 업그레이드 활성화"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "변경사항 즉시 적용 (프로덕션에서는 false 권장)"
  type        = bool
  default     = false
}

# 추가 보안 변수들
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

variable "manage_master_user_password" {
  description = "AWS 관리형 마스터 사용자 비밀번호 사용 (자동 생성 및 로테이션)"
  type        = bool
  default     = true
}