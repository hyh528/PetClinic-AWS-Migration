# =============================================================================
# Network Layer - VPC 및 엔드포인트 구성
# =============================================================================
# 목적: AWS Well-Architected 네트워킹 원칙에 따른 기본 네트워크 구성
# 의존성: 없음 (기본 레이어)

terraform {
  backend "s3" {
    bucket  = "petclinic-yeonghyeon-test"
    key     = "dev/01-network/terraform.tfstate"
    region  = "ap-northeast-1"
    profile = "petclinic-dev"
    encrypt = true
    dynamodb_table = "petclinic-yeonghyeon-test-locks"
  }
}

locals {
  common_network_tags = merge(var.shared_config.common_tags, {
    Layer     = "01-network"
    Component = "networking"
  })
}

# VPC 및 서브넷 모듈
module "vpc" {
  source = "../../modules/vpc"

  name_prefix = var.shared_config.name_prefix
  environment = var.shared_config.environment

  vpc_cidr    = var.network_config.vpc_cidr
  enable_ipv6 = var.enable_ipv6

  azs                      = var.network_config.azs
  public_subnet_cidrs      = var.network_config.public_subnet_cidrs
  private_app_subnet_cidrs = var.network_config.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.network_config.private_db_subnet_cidrs

  create_nat_per_az = var.create_nat_per_az
  tags              = local.common_network_tags
}

# VPC 엔드포인트 모듈
module "vpc_endpoints" {
  source = "../../modules/endpoints"

  name_prefix = var.shared_config.name_prefix
  environment = var.shared_config.environment

  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.network_config.vpc_cidr

  interface_subnet_ids        = values(module.vpc.private_app_subnet_ids)
  public_route_table_id       = module.vpc.public_route_table_id
  private_app_route_table_ids = module.vpc.private_app_route_table_ids
  private_db_route_table_ids  = module.vpc.private_db_route_table_ids
  interface_services          = var.vpc_endpoint_services
  tags                        = local.common_network_tags
}