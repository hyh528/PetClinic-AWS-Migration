# 네트워크 레이어 변수

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

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_ipv6" {
  description = "VPC 및 서브넷에 IPv6 (듀얼스택) 활성화"
  type        = bool
  default     = true
}

variable "azs" {
  description = "서브넷 CIDR과 일치하는 가용 영역"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 IPv4 CIDR (AZ당 하나)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "프라이빗 앱 서브넷 IPv4 CIDR (AZ당 하나)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "프라이빗 DB 서브넷 IPv4 CIDR (AZ당 하나)"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "create_nat_per_az" {
  description = "HA를 위해 AZ당 하나의 NAT 게이트웨이 생성 (비용 더 많이 듦)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "모든 리소스에 병합되는 추가 태그 (provider default_tags도 적용됨)"
  type        = map(string)
  default     = {}
}

# ==========================================
# Provider 변수 (인터랙티브 프롬프트 방지)
# ==========================================

variable "aws_region" {
  description = "리소스를 배포할 AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "공유 AWS CLI 프로필 (모든 레이어에서 동일하게 사용)"
  type        = string
  default     = "petclinic-dev"
}
