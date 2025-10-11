# =============================================================================
# Application Layer - 애플리케이션 인프라 (단순화됨)
# =============================================================================
# 목적: 단일 책임 원칙 적용 - ECR, ALB, ECS 모듈 분리
# 의존성: 01-network, 02-security, 03-database 레이어

# 공통 로컬 변수
locals {
  # Network 레이어에서 필요한 정보
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids = values(data.terraform_remote_state.network.outputs.public_subnet_ids)
  private_app_subnet_ids = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)

  # Security 레이어에서 필요한 정보
  ecs_task_execution_role_arn = data.terraform_remote_state.security.outputs.ecs_task_execution_role_arn
  ecs_security_group_id = data.terraform_remote_state.security.outputs.ecs_security_group_id

  common_tags = merge(var.shared_config.common_tags, {
    Layer     = "07-application"
    Component = "application-infrastructure"
  })
}

# =============================================================================
# ECR 모듈 (Docker 이미지 저장소)
# =============================================================================

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.repository_name != null ? var.repository_name : "${var.shared_config.name_prefix}-app"
  tags            = local.common_tags
}

# =============================================================================
# ALB 모듈 (로드 밸런서)
# =============================================================================

module "alb" {
  source = "../../modules/alb"

  name_prefix = var.shared_config.name_prefix
  environment = var.shared_config.environment

  vpc_id            = local.vpc_id
  public_subnet_ids = local.public_subnet_ids

  tags = local.common_tags
}

# =============================================================================
# ECS 모듈 (컨테이너 실행 환경) - 단순화됨
# =============================================================================

module "ecs" {
  source = "../../modules/ecs"

  cluster_name       = var.cluster_name != null ? var.cluster_name : "${var.shared_config.name_prefix}-cluster"
  task_family        = var.task_family != null ? var.task_family : "${var.shared_config.name_prefix}-app"
  execution_role_arn = local.ecs_task_execution_role_arn

  container_definitions = var.container_definitions

  # 네트워크 설정
  subnets         = local.private_app_subnet_ids
  security_groups = [local.ecs_security_group_id]

  # ALB 통합
  target_group_arn = module.alb.default_target_group_arn
  container_name   = var.container_name
  container_port   = var.container_port

  tags = local.common_tags
}