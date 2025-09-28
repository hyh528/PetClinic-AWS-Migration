# NACL 모듈 변수 파일
# 이 파일은 Network ACL (Access Control List) 모듈에서 사용하는 변수들을 정의합니다.
# NACL은 서브넷 수준의 보안 규칙을 설정합니다.

# name_prefix: 모든 리소스 이름의 시작 부분입니다. 환경을 구분하기 위해 사용합니다.
variable "name_prefix" {
  description = "리소스 이름 접두사, 예: petclinic-dev"
  type        = string
}

variable "environment" {
  description = "환경 레이블, 예: dev|stg|prd"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR 블록"
  type        = string
}

variable "vpc_ipv6_cidr" {
  description = "VPC IPv6 CIDR 블록 (IPv6 비활성화 시 비어 있음)"
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  type        = list(string)
}

variable "private_app_subnet_ids" {
  description = "프라이빗 앱 서브넷 ID 목록"
  type        = list(string)
}

variable "private_db_subnet_ids" {
  description = "프라이빗 DB 서브넷 ID 목록"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "프라이빗 앱 서브넷의 IPv4 CIDR 블록"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "프라이빗 DB 서브넷의 IPv4 CIDR 블록"
  type        = list(string)
}

variable "tags" {
  description = "공통 리소스 태그"
  type        = map(string)
  default     = {}
}