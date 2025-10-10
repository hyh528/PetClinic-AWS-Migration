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
  description = "Aurora 클러스터 인스턴스 클래스"
  type        = string
  default     = "db.t3.small" # Aurora는 더 작은 인스턴스로 시작 가능
}

variable "engine_version" {
  description = "Aurora MySQL 엔진 버전"
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
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

# ==========================================
# Backend/Provider/Remote State 공통 변수 (표준화)
# ==========================================
# - providers.tf에서 참조하는 공통 입력값들

variable "tfstate_bucket_name" {
  description = "Terraform 원격 상태 보관용 S3 버킷 이름"
  type        = string
  default     = "petclinic-tfstate-team-jungsu-kopo"
}

variable "tf_lock_table_name" {
  description = "Terraform 상태 잠금을 위한 DynamoDB 테이블 이름"
  type        = string
  default     = "petclinic-tf-locks-jungsu-kopo"
}

variable "aws_region" {
  description = "리소스를 배포할 AWS 리전 (예: ap-northeast-2)"
  type        = string
  default     = "ap-northeast-2"
}

variable "encrypt_state" {
  description = "원격 상태 암호화 사용 여부"
  type        = bool
  default     = true
}

# 공유 AWS CLI 프로필 (모든 레이어에서 동일하게 사용)
variable "aws_profile" {
  description = "공유 AWS CLI 프로필 (모든 레이어에서 동일하게 사용)"
  type        = string
  default     = "petclinic-dev"
}

# 원격 상태 접근 프로파일 (공유 프로필 사용)
variable "network_state_profile" {
  description = "Network 레이어 원격 상태(S3) 접근을 위한 AWS CLI 프로필"
  type        = string
  default     = "petclinic-dev"
}

variable "security_state_profile" {
  description = "Security 레이어 원격 상태(S3) 접근을 위한 AWS CLI 프로필"
  type        = string
  default     = "petclinic-dev"
}