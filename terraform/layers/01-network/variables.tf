# =============================================================================
# Network Layer Variables - 공유 변수 사용
# =============================================================================
# 설명: shared-variables.tf에서 정의된 공유 변수를 사용하여 중복 제거

# =============================================================================
# 공유 설정
# =============================================================================

variable "shared_config" {
  description = "공유 설정 정보"
  type = object({
    name_prefix = string
    environment = string
    aws_region  = string
    common_tags = map(string)
  })
}

variable "network_config" {
  description = "네트워크 공통 설정"
  type = object({
    vpc_cidr                 = string
    azs                      = list(string)
    public_subnet_cidrs      = list(string)
    private_app_subnet_cidrs = list(string)
    private_db_subnet_cidrs  = list(string)
  })
}

# =============================================================================
# 네트워크 설정(dev.tfvars에서 정의)
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
