# =============================================================================
# Network Layer Variables - 공유 변수 사용
# =============================================================================
# 설명: shared-variables.tf에서 정의된 공유 변수를 사용하여 중복 제거

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

# VPC 엔드포인트 서비스 목록
variable "vpc_endpoint_services" {
  description = "생성할 VPC 엔드포인트 서비스 목록"
  type        = list(string)
  default = [
    "ssm",
    "secretsmanager", 
    "ecr.api",
    "ecr.dkr",
    "logs",
    "xray",
    "kms",
    "monitoring"
  ]
}