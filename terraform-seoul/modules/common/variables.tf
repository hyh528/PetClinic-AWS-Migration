variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "aws_profile" {
  description = "AWS 프로파일"
  type        = string
}

variable "tags" {
  description = "기본 태그 맵"
  type        = map(string)
  default     = {}
}

variable "layer" {
  description = "레이어 이름 (01-network, 02-security 등)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "cost_center" {
  description = "비용 센터"
  type        = string
  default     = ""
}

variable "owner" {
  description = "소유자"
  type        = string
  default     = ""
}

variable "backup_required" {
  description = "백업 필요 여부"
  type        = bool
  default     = false
}

variable "monitoring_enabled" {
  description = "모니터링 활성화 여부"
  type        = bool
  default     = true
}

variable "compliance_level" {
  description = "컴플라이언스 레벨"
  type        = string
  default     = "standard"
}

variable "terraform_module" {
  description = "Terraform 모듈 이름"
  type        = string
  default     = "common"
}

variable "component" {
  description = "컴포넌트 이름"
  type        = string
  default     = ""
}

variable "additional_tags" {
  description = "추가 태그 맵"
  type        = map(string)
  default     = {}
}