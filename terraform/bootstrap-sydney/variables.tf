# ==========================================
# Bootstrap: 변수 선언 (클린 아키텍처)
# - main.tf에 몰빵하지 않고 역할 분리
# - 지역/프로파일/버킷/락테이블 이름을 변수로 표준화
# ==========================================

variable "aws_region" {
  description = "Bootstrap 리소스를 생성할 AWS 리전"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "Bootstrap에 사용할 AWS CLI 프로파일"
  type        = string
  default     = "petclinic-dev"
}

variable "tfstate_bucket_name" {
  description = "Terraform 원격 상태(S3) 버킷 이름 (전역 유일)"
  type        = string
  default     = "petclinic-tfstate-sydney-dev"
}

variable "tf_lock_table_name" {
  description = "Terraform 상태 잠금(DynamoDB) 테이블 이름 (리전 유일)"
  type        = string
  default     = "petclinic-tf-locks-sydney-dev"
}