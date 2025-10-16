variable "project_name" {
  description = "프로젝트 이름 (리소스 태깅 및 이름에 사용)"
  type        = string
  default     = "petclinic-dev"
}

variable "environment" {
  description = "배포 환경 (e.g., dev, stg, prod)"
  type        = string
  default     = "dev"
}

variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
  default     = "petclinic"
}