# ==========================================
# Bootstrap: 변수 선언 (클린 아키텍처) - Seoul 리전
# - main.tf에 몰빵하지 않고 역할 분리
# - 지역/프로파일/버킷 이름을 변수로 표준화
# ==========================================

variable "aws_region" {
  description = "Bootstrap 리소스를 생성할 AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "Bootstrap에 사용할 AWS CLI 프로파일"
  type        = string
  default     = "petclinic-dev"
}

variable "tfstate_bucket_name" {
  description = "Terraform 원격 상태(S3) 버킷 이름 (전역 유일)"
  type        = string
  default     = "petclinic-tfstate-seoul-dev"
}

