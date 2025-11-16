# =============================================================================
# Security Layer - 로컬 값 정의
# =============================================================================
# 목적: 보안 그룹 및 IAM 역할 구성에 필요한 로컬 값들을 정의

locals {
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr = data.terraform_remote_state.network.outputs.vpc_cidr

  vpce_security_group_id = try(
    data.terraform_remote_state.network.outputs.vpce_security_group_id,
    ""
  )

  alb_sg_id = "" # Application layer not deployed yet

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