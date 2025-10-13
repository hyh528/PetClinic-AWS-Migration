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