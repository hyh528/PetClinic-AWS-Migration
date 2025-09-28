# Network 레이어: VPC 기반 인프라

module "vpc" {
  source = "../../../modules/vpc"

  name_prefix = var.name_prefix
  environment = var.environment

  vpc_cidr    = var.vpc_cidr
  enable_ipv6 = var.enable_ipv6

  azs                     = var.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs

  create_nat_per_az = var.create_nat_per_az

  tags = var.tags
}

# 참고:
# - 보안(IAM, SG, VPC Endpoints)은 security/ 환경에서 관리
# - L7(예: ALB, ECS)은 application/ 환경에서 관리