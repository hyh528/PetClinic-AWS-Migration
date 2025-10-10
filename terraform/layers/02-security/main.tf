# =============================================================================
# Security Layer - 보안 그룹, IAM 역할 및 정책
# =============================================================================
# 목적: AWS Well-Architected 보안 원칙에 따른 네트워크 및 접근 제어
# 의존성: 01-network 레이어 (VPC, 서브넷, VPC 엔드포인트)

# 공통 로컬 변수
locals {
  # 보안 그룹 공통 설정 (공유 변수 시스템 사용)
  common_security_tags = merge(var.shared_config.common_tags, {
    Layer     = "02-security"
    Component = "security"
  })
}

# =============================================================================
# 1. 보안 그룹 모듈 (ECS, RDS, ALB용)
# =============================================================================

module "security_groups" {
  source = "../../modules/security"

  # 기본 설정 (공유 변수 시스템 사용)
  name_prefix = var.shared_config.name_prefix
  environment = var.shared_config.environment
  vpc_id      = local.vpc_id
  aws_region  = var.shared_config.aws_region

  # ALB 보안 그룹 ID (Cross-Layer 참조)
  # Phase 1: 빈 값 (application 레이어 배포 전)
  # Phase 2: terraform_remote_state로 참조 (application 레이어 배포 후)
  alb_security_group_id = local.alb_sg_id

  # VPC 엔드포인트 보안 그룹 ID (network 레이어에서 생성된 것 참조)
  vpce_security_group_id = local.vpce_security_group_id

  tags = local.common_security_tags
}

# =============================================================================
# 2. IAM 역할 및 정책 모듈
# =============================================================================

module "iam_roles" {
  source = "../../modules/iam"

  # 기본 설정 (공유 변수 시스템 사용)
  project_name = var.shared_config.name_prefix

  # 팀 멤버 목록 (변수로 관리)
  team_members = var.team_members

  # 역할 기반 정책 활성화 여부 (변수로 관리)
  enable_role_based_policies = var.enable_role_based_policies
}