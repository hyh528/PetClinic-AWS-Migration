# =============================================================================
# Network Layer - VPC 기반 네트워크 인프라
# =============================================================================
# 목적: AWS Well-Architected 네트워킹 원칙에 따른 기본 네트워크 구성
# 의존성: 없음 (기반 레이어)

# 공통 로컬 변수
locals {
  # 네트워크 공통 설정 (공유 변수 시스템 사용)
  common_network_tags = merge(var.shared_config.common_tags, {
    Layer     = "01-network"
    Component = "networking"
  })
}

# =============================================================================
# 1. VPC 및 서브넷 모듈
# =============================================================================

module "vpc" {
  source = "../../modules/vpc"

  # 기본 설정 (공유 변수 시스템 사용)
  name_prefix = var.shared_config.name_prefix
  environment = var.shared_config.environment

  # VPC 설정 (공유 변수 시스템 사용)
  vpc_cidr    = var.network_config.vpc_cidr
  enable_ipv6 = var.enable_ipv6

  # 서브넷 설정 (공유 변수 시스템 사용)
  azs                      = var.network_config.azs
  public_subnet_cidrs      = var.network_config.public_subnet_cidrs
  private_app_subnet_cidrs = var.network_config.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.network_config.private_db_subnet_cidrs

  # NAT Gateway 설정
  create_nat_per_az = var.create_nat_per_az

  tags = local.common_network_tags
}

# =============================================================================
# 2. VPC 엔드포인트 모듈
# =============================================================================

module "vpc_endpoints" {
  source = "../../modules/endpoints"

  # 기본 설정 (공유 변수 시스템 사용)
  name_prefix = var.shared_config.name_prefix
  environment = var.shared_config.environment

  # VPC 정보 (공유 변수 시스템 사용)
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.network_config.vpc_cidr

  # 엔드포인트 배치 서브넷 (private app 서브넷)
  interface_subnet_ids = values(module.vpc.private_app_subnet_ids)

  # 라우팅 테이블 정보 (S3 게이트웨이 엔드포인트용)
  public_route_table_id       = module.vpc.public_route_table_id
  private_app_route_table_ids = module.vpc.private_app_route_table_ids
  private_db_route_table_ids  = module.vpc.private_db_route_table_ids

  # 생성할 인터페이스 서비스 목록
  interface_services = var.vpc_endpoint_services

  tags = local.common_network_tags
}