variable "name_prefix" {
  description = "리소스 이름 접두사, 예: petclinic-dev"
  type        = string
}

variable "environment" {
  description = "환경 레이블, 예: dev|stg|prd"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC용 IPv4 CIDR, 예: 10.0.0.0/16"
  type        = string
}

variable "enable_ipv6" {
  description = "VPC 및 서브넷에 IPv6 활성화 (듀얼스택)"
  type        = bool
  default     = true
}

variable "azs" {
  description = "AZ 목록, 인덱스는 서브넷 CIDR 목록과 정렬되어야 함, 예: [\"ap-northeast-2a\",\"ap-northeast-2c\"]"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷용 IPv4 CIDR, AZ당 하나, 예: [\"10.0.1.0/24\",\"10.0.2.0/24\"]"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "프라이빗 앱 서브넷용 IPv4 CIDR, AZ당 하나, 예: [\"10.0.3.0/24\",\"10.0.4.0/24\"]"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "프라이빗 DB 서브넷용 IPv4 CIDR, AZ당 하나, 예: [\"10.0.5.0/24\",\"10.0.6.0/24\"]"
  type        = list(string)
}

variable "create_nat_per_az" {
  description = "HA를 위한 AZ당 NAT 게이트웨이 하나 생성"
  type        = bool
  default     = true
}

variable "tags" {
  description = "공통 리소스 태그"
  type        = map(string)
  default     = {}
}