variable "aws_region" {
  description = "리소스용 AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "인증용 AWS 프로필"
  type        = string
  default     = "petclinic-hwigwon"
}

variable "environment" {
  description = "배포 환경 (예: dev, prod)"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "리소스 이름에 사용될 접두사"
  type        = string
  default     = "petclinic"
}

variable "network_state_profile" {
  description = "프로젝트의 network 레이어 Terraform 상태를 읽어올 AWS 프로필"
  type        = string
  default     = "petclinic-yeonghyeon"
}

variable "database_state_profile" {
  description = "프로젝트의 database 레이어 Terraform 상태를 읽어올 AWS 프로필"
  type        = string
  default     = "petclinic-junje"
}

variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일을 저장할 S3 버킷 이름"
  type        = string
  default     = "petclinic-tfstate-team-jungsu-kopo"
}

variable "tf_lock_table_name" {
  description = "Terraform 상태 잠금을 위한 DynamoDB 테이블 이름"
  type        = string
  default     = "petclinic-tf-locks-jungsu-kopo"
}

variable "encrypt_state" {
  description = "Terraform 상태 파일 암호화 여부"
  type        = bool
  default     = true
}
