# Database 모듈 변수들

variable "name_prefix" {
  description = "리소스 이름 접두사, e.g., petclinic-dev"
  type        = string
}

variable "private_db_subnet_ids" {
  description = "DB 서브넷 그룹에 사용할 프라이빗 DB 서브넷 ID 목록"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "RDS에 적용할 보안 그룹 ID 목록"
  type        = list(string)
}

variable "engine_version" {
  description = "Aurora MySQL 엔진 버전"
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
}

variable "instance_class" {
  description = "Aurora 인스턴스 클래스"
  type        = string
  default     = "db.t3.small"
}

variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
  default     = "petclinic"
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
}

variable "backup_retention_period" {
  description = "백업 보존 기간 (일)"
  type        = number
  default     = 7
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}