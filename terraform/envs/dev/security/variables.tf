# ==========================================
# Security 환경 공통 변수 선언
# ==========================================

# 원격 상태(S3) 버킷 이름
variable "tfstate_bucket_name" {
  description = "Terraform 원격 상태 보관용 S3 버킷 이름"
  type        = string
  default     = "petclinic-tfstate-team-jungsu-kopo"
}

# 상태 잠금(DynamoDB) 테이블 이름
variable "tf_lock_table_name" {
  description = "Terraform 상태 잠금을 위한 DynamoDB 테이블 이름"
  type        = string
  default     = "petclinic-tf-locks-jungsu-kopo"
}

# 리전
variable "aws_region" {
  description = "리소스를 배포할 AWS 리전 (예: ap-northeast-2)"
  type        = string
  default     = "ap-northeast-2"
}

# 상태 암호화 사용 여부
variable "encrypt_state" {
  description = "원격 상태 암호화 사용 여부"
  type        = bool
  default     = true
}

# 이 환경에서 리소스를 생성/변경하는 기본 AWS CLI 프로파일
variable "aws_profile" {
  description = "Security 레이어에서 사용하는 기본 AWS CLI 프로파일"
  type        = string
  default     = "petclinic-hwigwon"
}

# 원격 상태 접근 프로파일(네트워크 상태 참조)
variable "network_state_profile" {
  description = "Network 레이어 원격 상태(S3) 접근을 위한 AWS CLI 프로파일"
  type        = string
  default     = "petclinic-yeonghyeon"
}

# 네이밍/태깅을 위한 표준 값
variable "name_prefix" {
  description = "리소스 이름 접두사, 예: petclinic-dev"
  type        = string
  default     = "petclinic-dev"
}

variable "environment" {
  description = "환경 레이블, 예: dev|stg|prd"
  type        = string
  default     = "dev"
}