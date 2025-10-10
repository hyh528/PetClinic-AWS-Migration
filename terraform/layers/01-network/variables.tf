# =============================================================================
# Network Layer Variables - 공유 변수 시스템 적용
# =============================================================================
# 목적: shared-variables.tf에서 정의된 공통 변수를 사용하여 일관성 확보

# 공유 설정 (shared-variables.tf에서 전달)
variable "shared_config" {
  description = "공유 설정 정보 (shared-variables.tf에서 전달)"
  type = object({
    name_prefix = string
    environment = string
    aws_region  = string
    aws_profile = string
    common_name = string
    common_tags = map(string)
  })
}

# 네트워크 설정 (shared-variables.tf에서 전달)
variable "network_config" {
  description = "네트워크 공통 설정 (shared-variables.tf에서 전달)"
  type = object({
    vpc_cidr                 = string
    azs                      = list(string)
    az_indexes               = map(string)
    public_subnet_cidrs      = list(string)
    private_app_subnet_cidrs = list(string)
    private_db_subnet_cidrs  = list(string)
  })
}

# =============================================================================
# Network 레이어 특화 변수
# =============================================================================

variable "enable_ipv6" {
  description = "VPC 및 서브넷에 IPv6 (듀얼스택) 활성화"
  type        = bool
  default     = true
}

variable "create_nat_per_az" {
  description = "HA를 위해 AZ당 하나의 NAT 게이트웨이 생성"
  type        = bool
  default     = true
}

variable "vpc_endpoint_services" {
  description = "생성할 VPC 인터페이스 엔드포인트 서비스 목록"
  type        = list(string)
  default = [
    "ecr.api",
    "ecr.dkr",
    "logs",
    "xray",
    "ssm",
    "ssmmessages",
    "ec2messages",
    "secretsmanager",
    "kms",
    "monitoring"
  ]
}
