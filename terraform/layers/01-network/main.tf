# =============================================================================
# Network Layer - VPC 및 엔드포인트 구성
# =============================================================================
# 목적: AWS Well-Architected 네트워킹 원칙에 따른 기본 네트워크 구성
# 의존성: 없음 (기본 레이어)

# 공통 모듈에서 provider 설정 상속

locals {
  # 공통 모듈에서 태그 가져오기
  common_network_tags = module.common.get_tags_for_layer
}

# 공통 모듈 (공통 변수들은 terraform plan/apply 시 -var-file로 전달됨)
module "common" {
  source = "../../modules/common"

  # 공통 변수들은 terraform plan/apply 시 -var-file로 전달됨
  name_prefix  = var.name_prefix
  environment  = var.environment
  aws_region   = var.aws_region
  aws_profile  = var.aws_profile
  tags         = var.tags
  layer        = "01-network"
  project_name = "petclinic"
  cost_center  = "training"
  owner        = "team-petclinic"
}

# VPC 및 서브넷 모듈
module "vpc" {
  source = "../../modules/vpc"

  name_prefix = var.name_prefix
  environment = var.environment

  vpc_cidr    = var.vpc_cidr
  enable_ipv6 = var.enable_ipv6

  azs                      = var.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs

  create_nat_per_az = var.create_nat_per_az
  tags              = module.common.get_tags_for_layer
}

# VPC 엔드포인트 모듈
module "vpc_endpoints" {
  source = "../../modules/endpoints"

  name_prefix = var.name_prefix
  environment = var.environment

  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr

  interface_subnet_ids        = values(module.vpc.private_app_subnet_ids)
  public_route_table_id       = module.vpc.public_route_table_id
  private_app_route_table_ids = module.vpc.private_app_route_table_ids
  private_db_route_table_ids  = module.vpc.private_db_route_table_ids
  interface_services          = var.vpc_endpoint_services
  tags                        = module.common.get_tags_for_layer
}