variable "name_prefix" {
  description = "리소스 이름 접두사, 예: petclinic-dev"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.name_prefix)) && length(var.name_prefix) >= 3 && length(var.name_prefix) <= 63
    error_message = "name_prefix는 3-63자의 소문자, 숫자, 하이픈만 사용 가능하며, 하이픈으로 시작하거나 끝날 수 없습니다."
  }
}

variable "environment" {
  description = "환경 레이블, 예: dev|stg|prd"
  type        = string

  validation {
    condition     = contains(["dev", "development", "stg", "staging", "prd", "prod", "production", "test", "testing"], var.environment)
    error_message = "environment는 다음 중 하나여야 합니다: dev, development, stg, staging, prd, prod, production, test, testing"
  }
}

variable "vpc_cidr" {
  description = "VPC용 IPv4 CIDR, 예: 10.0.0.0/16"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR은 유효한 IPv4 CIDR 블록이어야 합니다."
  }

  validation {
    condition     = can(regex("^10\\.", var.vpc_cidr)) || can(regex("^172\\.(1[6-9]|2[0-9]|3[0-1])\\.", var.vpc_cidr)) || can(regex("^192\\.168\\.", var.vpc_cidr))
    error_message = "VPC CIDR은 RFC 1918 사설 IP 대역이어야 합니다 (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)."
  }

  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 28
    error_message = "VPC CIDR 서브넷 마스크는 /16에서 /28 사이여야 합니다."
  }
}

variable "enable_ipv6" {
  description = "VPC 및 서브넷에 IPv6 활성화 (듀얼스택)"
  type        = bool
  default     = true
}

variable "azs" {
  description = "AZ 목록, 인덱스는 서브넷 CIDR 목록과 정렬되어야 함, 예: [\"ap-northeast-2a\",\"ap-northeast-2c\"]"
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 6
    error_message = "최소 2개, 최대 6개의 가용 영역을 지정해야 합니다 (고가용성 및 비용 최적화)."
  }

  validation {
    condition = alltrue([
      for az in var.azs : can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", az))
    ])
    error_message = "AZ 이름은 AWS 표준 형식이어야 합니다 (예: ap-northeast-2a)."
  }

  validation {
    condition     = length(var.azs) == length(distinct(var.azs))
    error_message = "AZ 목록에 중복된 값이 있습니다."
  }
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷용 IPv4 CIDR, AZ당 하나, 예: [\"10.0.1.0/24\",\"10.0.2.0/24\"]"
  type        = list(string)

  validation {
    condition = alltrue([
      for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "모든 퍼블릭 서브넷 CIDR이 유효한 IPv4 CIDR 블록이어야 합니다."
  }

  validation {
    condition = alltrue([
      for cidr in var.public_subnet_cidrs :
      tonumber(split("/", cidr)[1]) >= 20 && tonumber(split("/", cidr)[1]) <= 28
    ])
    error_message = "퍼블릭 서브넷 CIDR 서브넷 마스크는 /20에서 /28 사이여야 합니다."
  }

  validation {
    condition     = length(var.public_subnet_cidrs) == length(distinct(var.public_subnet_cidrs))
    error_message = "퍼블릭 서브넷 CIDR 목록에 중복된 값이 있습니다."
  }
}

variable "private_app_subnet_cidrs" {
  description = "프라이빗 앱 서브넷용 IPv4 CIDR, AZ당 하나, 예: [\"10.0.3.0/24\",\"10.0.4.0/24\"]"
  type        = list(string)

  validation {
    condition = alltrue([
      for cidr in var.private_app_subnet_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "모든 프라이빗 앱 서브넷 CIDR이 유효한 IPv4 CIDR 블록이어야 합니다."
  }

  validation {
    condition = alltrue([
      for cidr in var.private_app_subnet_cidrs :
      tonumber(split("/", cidr)[1]) >= 20 && tonumber(split("/", cidr)[1]) <= 28
    ])
    error_message = "프라이빗 앱 서브넷 CIDR 서브넷 마스크는 /20에서 /28 사이여야 합니다."
  }

  validation {
    condition     = length(var.private_app_subnet_cidrs) == length(distinct(var.private_app_subnet_cidrs))
    error_message = "프라이빗 앱 서브넷 CIDR 목록에 중복된 값이 있습니다."
  }
}

variable "private_db_subnet_cidrs" {
  description = "프라이빗 DB 서브넷용 IPv4 CIDR, AZ당 하나, 예: [\"10.0.5.0/24\",\"10.0.6.0/24\"]"
  type        = list(string)

  validation {
    condition = alltrue([
      for cidr in var.private_db_subnet_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "모든 프라이빗 DB 서브넷 CIDR이 유효한 IPv4 CIDR 블록이어야 합니다."
  }

  validation {
    condition = alltrue([
      for cidr in var.private_db_subnet_cidrs :
      tonumber(split("/", cidr)[1]) >= 24 && tonumber(split("/", cidr)[1]) <= 28
    ])
    error_message = "프라이빗 DB 서브넷 CIDR 서브넷 마스크는 /24에서 /28 사이여야 합니다 (보안상 더 작은 서브넷 권장)."
  }

  validation {
    condition     = length(var.private_db_subnet_cidrs) == length(distinct(var.private_db_subnet_cidrs))
    error_message = "프라이빗 DB 서브넷 CIDR 목록에 중복된 값이 있습니다."
  }
}

variable "create_nat_per_az" {
  description = "HA를 위한 AZ당 NAT 게이트웨이 하나 생성 (비용 vs 가용성 트레이드오프)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "공통 리소스 태그"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.tags : can(regex("^[a-zA-Z0-9+\\-=._:/@\\s]+$", k)) && can(regex("^[a-zA-Z0-9+\\-=._:/@\\s]*$", v))
    ])
    error_message = "태그 키와 값은 AWS 태그 명명 규칙을 준수해야 합니다."
  }

  validation {
    condition = alltrue([
      for k, v in var.tags : length(k) <= 128 && length(v) <= 256
    ])
    error_message = "태그 키는 128자, 값은 256자를 초과할 수 없습니다."
  }
}

# 추가 검증 변수들
variable "enable_dns_hostnames" {
  description = "VPC에서 DNS 호스트 이름 활성화"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "VPC에서 DNS 해석 활성화"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 생성 여부 (비용 절약을 위해 비활성화 가능)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "단일 NAT Gateway 사용 (비용 절약, 가용성 감소)"
  type        = bool
  default     = false
}

variable "map_public_ip_on_launch" {
  description = "퍼블릭 서브넷에서 인스턴스 시작 시 자동으로 퍼블릭 IP 할당"
  type        = bool
  default     = true
}