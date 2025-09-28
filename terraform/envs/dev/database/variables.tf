# Database 레이어 변수들 (준제 전용)

variable "name_prefix" {
  description = "리소스 이름 접두사, e.g., petclinic-dev"
  type        = string
  default     = "petclinic-dev"
}

variable "private_db_subnet_ids" {
  description = "DB 서브넷 그룹에 사용할 프라이빗 DB 서브넷 ID 목록"
  type        = list(string)
}

variable "instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "할당된 저장소 크기 (GB)"
  type        = number
  default     = 20
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

variable "db_password" {
  description = "데이터베이스 비밀번호 (실무에서는 AWS Secrets Manager 사용 권장)"
  type        = string
  sensitive   = true
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