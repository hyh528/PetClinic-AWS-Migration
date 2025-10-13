# =============================================================================
# Network Layer Variables
# =============================================================================
# 설명: 레이어 전용 변수만 정의 (공통 변수는 shared/common.tfvars에서 로드)

# =============================================================================
# 공통 변수 (shared/common.tfvars에서 로드)
# =============================================================================

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "name_prefix" {
  description = "모든 리소스 이름의 접두사"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "azs" {
  description = "사용할 가용 영역 목록"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "프라이빗 앱 서브넷 CIDR 목록"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "프라이빗 DB 서브넷 CIDR 목록"
  type        = list(string)
}

variable "vpc_endpoint_services" {
  description = "생성할 VPC 인터페이스 엔드포인트 서비스 목록"
  type        = list(string)
}

variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
}

# =============================================================================
# 네트워크 전용 변수
# =============================================================================

# VPC IPv6 설정
variable "enable_ipv6" {
  description = "IPv6 활성화 여부"
  type        = bool
  default     = false
}

# NAT 게이트웨이 설정
variable "create_nat_per_az" {
  description = "가용 영역당 NAT 게이트웨이 생성 여부"
  type        = bool
  default     = false
}
