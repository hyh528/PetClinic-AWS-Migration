# ==========================================
# 공통 표준 변수 정의
# ==========================================
# 클린 코드 원칙: 의미 있는 이름과 명확한 검증

# ==========================================
# 필수 변수 (모든 환경에서 필요)
# ==========================================
variable "project_name" {
  description = "프로젝트 이름 (소문자, 하이픈 허용)"
  type        = string
  default     = "petclinic"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "프로젝트 이름은 소문자로 시작하고, 소문자, 숫자, 하이픈만 포함해야 합니다."
  }
}

variable "environment" {
  description = "배포 환경"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

variable "terraform_module" {
  description = "현재 Terraform 모듈 이름"
  type        = string
  default     = "common"
}

variable "layer" {
  description = "아키텍처 레이어 (network, security, database, application, aws-native, monitoring)"
  type        = string

  validation {
    condition = contains([
      "network", "security", "database", 
      "application", "aws-native", "monitoring"
    ], var.layer)
    error_message = "레이어는 정의된 아키텍처 레이어 중 하나여야 합니다."
  }
}

variable "component" {
  description = "컴포넌트 이름 (vpc, ecs, rds, api-gateway 등)"
  type        = string
  default     = ""
}

# ==========================================
# 비용 관리 변수
# ==========================================
variable "cost_center" {
  description = "비용 센터 코드"
  type        = string
  default     = "training"

  validation {
    condition     = length(var.cost_center) > 0
    error_message = "비용 센터는 비어있을 수 없습니다."
  }
}

variable "owner" {
  description = "리소스 소유자/팀"
  type        = string
  default     = "team-petclinic"

  validation {
    condition     = length(var.owner) > 0
    error_message = "소유자는 비어있을 수 없습니다."
  }
}

# ==========================================
# 운영 관리 변수
# ==========================================
variable "backup_required" {
  description = "백업 필요 여부"
  type        = bool
  default     = true
}

variable "monitoring_enabled" {
  description = "모니터링 활성화 여부"
  type        = bool
  default     = true
}

variable "compliance_level" {
  description = "컴플라이언스 레벨 (low, medium, high)"
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["low", "medium", "high"], var.compliance_level)
    error_message = "컴플라이언스 레벨은 low, medium, high 중 하나여야 합니다."
  }
}

# ==========================================
# 확장성 변수
# ==========================================
variable "additional_tags" {
  description = "추가 사용자 정의 태그"
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.additional_tags) <= 20
    error_message = "추가 태그는 최대 20개까지 설정 가능합니다."
  }
}

# ==========================================
# AWS 리전 변수
# ==========================================
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "유효한 AWS 리전 형식이어야 합니다 (예: ap-northeast-2)."
  }
}

# ==========================================
# 보안 변수
# ==========================================
variable "kms_deletion_window" {
  description = "KMS 키 삭제 대기 기간 (일)"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS 키 삭제 대기 기간은 7-30일 사이여야 합니다."
  }
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보존 기간 (일)"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "로그 보존 기간은 CloudWatch에서 지원하는 값 중 하나여야 합니다."
  }
}

variable "default_log_level" {
  description = "기본 로그 레벨"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.default_log_level)
    error_message = "로그 레벨은 DEBUG, INFO, WARN, ERROR 중 하나여야 합니다."
  }
}

variable "data_classification" {
  description = "데이터 분류 레벨"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "데이터 분류는 public, internal, confidential, restricted 중 하나여야 합니다."
  }
}

variable "compliance_requirements" {
  description = "컴플라이언스 요구사항"
  type        = string
  default     = "general"

  validation {
    condition     = length(var.compliance_requirements) > 0
    error_message = "컴플라이언스 요구사항은 비어있을 수 없습니다."
  }
}

variable "auto_shutdown_enabled" {
  description = "자동 종료 활성화 여부"
  type        = bool
  default     = false
}