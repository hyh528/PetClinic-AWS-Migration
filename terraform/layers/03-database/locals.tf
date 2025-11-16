# =============================================================================
# Database Layer - 로컬 값 정의
# =============================================================================
# 목적: Aurora MySQL 클러스터 구성에 필요한 로컬 값들을 정의

locals {
  # Network 레이어에서 필요한 정보
  private_db_subnet_ids = try(
    values(data.terraform_remote_state.network.outputs.private_db_subnet_ids),
    []
  )

  # VPC ID (추가 검증용)
  vpc_id = try(
    data.terraform_remote_state.network.outputs.vpc_id,
    null
  )

  # Security 레이어에서 필요한 정보
  aurora_security_group_id = try(
    data.terraform_remote_state.security.outputs.aurora_security_group_id,
    null
  )

  # 의존성 검증 로직
  network_ready = (
    length(local.private_db_subnet_ids) >= 2 && # 최소 2개 서브넷 필요 (Multi-AZ)
    local.vpc_id != null &&
    local.vpc_id != ""
  )

  security_ready = (
    local.aurora_security_group_id != null &&
    local.aurora_security_group_id != "" &&
    can(regex("^sg-[a-f0-9]+$", local.aurora_security_group_id)) # 보안 그룹 ID 형식 검증
  )

  # 전체 의존성 준비 상태
  dependencies_ready = local.network_ready && local.security_ready

  # 데이터베이스 공통 설정
  common_db_tags = merge(var.tags, {
    Layer     = "03-database"
    Component = "aurora-mysql"
    Purpose   = "petclinic-microservices"
  })

  # 디버깅 정보 (개발 시 유용)
  debug_info = {
    network_outputs_available  = length(keys(try(data.terraform_remote_state.network.outputs, {})))
    security_outputs_available = length(keys(try(data.terraform_remote_state.security.outputs, {})))
    subnet_count               = length(local.private_db_subnet_ids)
    vpc_id_present             = local.vpc_id != null
    security_group_valid       = local.security_ready
  }
}