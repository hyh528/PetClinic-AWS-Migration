# =============================================================================
# Security Layer - 보안 그룹 및 IAM 역할 구성
# =============================================================================
# 목적: AWS Well-Architected 보안 원칙에 따른 네트워크 및 접근 제어
# 의존성: 01-network 레이어(VPC, 서브넷, VPC 엔드포인트)


# 보안 그룹 모듈
module "security_groups" {
  source = "../../modules/security"

  name_prefix            = var.name_prefix
  environment            = var.environment
  vpc_id                 = local.vpc_id
  aws_region             = var.aws_region
  alb_security_group_id  = local.alb_sg_id
  vpce_security_group_id = local.vpce_security_group_id
  tags                   = local.common_security_tags
}

# IAM 역할 및 정책 모듈 (ECS 태스크 실행 역할 필요)
module "iam_roles" {
  source = "../../modules/iam"

  project_name               = var.name_prefix
  team_members               = var.team_members
  enable_role_based_policies = var.enable_role_based_policies
}