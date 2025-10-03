# VPC 엔드포인트 모듈에서 사용될 변수들을 정의합니다.

# VPC ID 변수 정의
variable "vpc_id" {
  description = "VPC 엔드포인트가 생성될 VPC의 ID입니다."
  type        = string
}

# 프라이빗 서브넷 ID 목록 변수 정의
variable "private_subnet_ids" {
  description = "VPC 엔드포인트가 배포될 프라이빗 서브넷 ID 목록입니다."
  type        = list(string)
}

# VPC 엔드포인트 보안 그룹 ID 변수 정의
variable "vpc_endpoint_sg_id" {
  description = "VPC 엔드포인트와 연결할 보안 그룹의 ID입니다."
  type        = string
}

# AWS 리전 변수 정의
variable "aws_region" {
  description = "리소스를 배포할 AWS 리전입니다."
  type        = string
}

# 프로젝트 이름 변수 정의
variable "project_name" {
  description = "리소스 태그에 사용될 프로젝트 이름입니다."
  type        = string
}

# 환경 변수 정의
variable "environment" {
  description = "리소스 태그에 사용될 환경 이름입니다 (예: dev, prod)."
  type        = string
}