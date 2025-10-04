variable "aws_region" {
  description = "리소스용 AWS 리전"
  type        = string
}

variable "aws_profile" {
  description = "인증용 AWS 프로필"
  type        = string
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
}