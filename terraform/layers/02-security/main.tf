# =============================================================================
# Security Layer - 보안 그룹 및 IAM 역할 구성
# =============================================================================
# 목적: AWS Well-Architected 보안 원칙에 따른 네트워크 및 접근 제어
# 의존성: 01-network 레이어(VPC, 서브넷, VPC 엔드포인트)

locals {
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr = data.terraform_remote_state.network.outputs.vpc_cidr

  vpce_security_group_id = try(
    data.terraform_remote_state.network.outputs.vpce_security_group_id,
    ""
  )

  alb_sg_id = var.enable_alb_integration && length(data.terraform_remote_state.application) > 0 ? (
    try(data.terraform_remote_state.application[0].outputs.alb_security_group_id, "")
  ) : ""

  # 공통 태그 계산
  common_tags = merge(var.tags, {
    Environment = var.environment
    Region      = var.aws_region
    Timestamp   = timestamp()
  })

  common_security_tags = merge(local.common_tags, {
    Layer     = "02-security"
    Component = "security"
  })
}

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

# IAM 역할 및 정책 모듈 (이미 생성됨 - 주석 처리)
# module "iam_roles" {
#   source = "../../modules/iam"

#   project_name               = var.shared_config.name_prefix
#   team_members               = var.team_members
#   enable_role_based_policies = var.enable_role_based_policies
# }