# =============================================================================
# 공유 변수 정의 (모든 레이어에서 공통으로 사용)
# =============================================================================
# 목적: 레이어 간 일관성을 위한 공통 변수 정의
# 사용법: 각 레이어에서 이 파일을 참조하여 변수 일관성 유지

# =============================================================================
# 기본 프로젝트 정보
# =============================================================================

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "PetClinic"
}

variable "name_prefix" {
  description = "모든 리소스 이름의 접두사"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix는 소문자, 숫자, 하이픈만 포함할 수 있습니다."
  }
}

variable "environment" {
  description = "배포 환경 (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment는 dev, staging, prod 중 하나여야 합니다."
  }
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "유효한 AWS 리전 형식이어야 합니다."
  }
}

variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
}

# =============================================================================
# 공통 태그
# =============================================================================

variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
}

# =============================================================================
# Terraform 상태 관리
# =============================================================================

variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일을 저장하는 S3 버킷 이름"
  type        = string
}

# =============================================================================
# 네트워크 공통 변수
# =============================================================================

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "유효한 CIDR 블록이어야 합니다."
  }
}

variable "azs" {
  description = "사용할 가용 영역 목록"
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "최소 2개의 가용 영역이 필요합니다."
  }
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


# =============================================================================
# 로컬 값 (계산된 공통 값들)
# =============================================================================

locals {
  # 공통 이름 생성 패턴
  common_name = "${var.name_prefix}-${var.environment}"

  # 공통 태그 (사용자 정의 태그와 기본 태그 병합)
  common_tags = merge(var.tags, {
    Environment = var.environment
    Region      = var.aws_region
    Timestamp   = timestamp()
  })

  # AZ 인덱스 매핑 (0, 1, 2, ...)
  az_indexes = { for i, az in var.azs : i => az }
}

# =============================================================================
# 출력값 (다른 레이어에서 참조 가능)
# =============================================================================

output "shared_config" {
  description = "공유 설정 정보"
  value = {
    name_prefix = var.name_prefix
    environment = var.environment
    aws_region  = var.aws_region
    aws_profile = var.aws_profile
    common_name = local.common_name
  }
}

output "network_config" {
  description = "네트워크 공통 설정"
  value = {
    vpc_cidr                 = var.vpc_cidr
    azs                      = var.azs
    az_indexes               = local.az_indexes
    public_subnet_cidrs      = var.public_subnet_cidrs
    private_app_subnet_cidrs = var.private_app_subnet_cidrs
    private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  }
}

output "state_config" {
  description = "Terraform 상태 관리 설정"
  value = {
    bucket_name = var.tfstate_bucket_name
    region      = var.aws_region
    profile     = var.aws_profile
  }
}