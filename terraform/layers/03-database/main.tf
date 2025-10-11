# =============================================================================
# Database Layer - Aurora MySQL 클러스터
# =============================================================================
# 목적: AWS Well-Architected 데이터베이스 원칙에 따른 Aurora 클러스터 구성
# 의존성: 01-network (서브넷), 02-security (보안 그룹)

# =============================================================================
# Local Values - 참조된 데이터 정리 및 검증
# =============================================================================

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

  # 데이터베이스 공통 설정 (공유 변수 서비스 사용)
  common_db_tags = merge(var.shared_config.common_tags, {
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
# =============================================================================
# Aurora MySQL 클러스터 모듈
# =============================================================================
module "aurora_cluster" {
  source = "../../modules/database"
  # 기본 설정 (공유 변수 서비스 사용)
  name_prefix = var.shared_config.name_prefix
  environment = var.shared_config.environment
  # Network 정보 (data.tf에서 참조)
  private_db_subnet_ids = local.private_db_subnet_ids
  # Security 정보 (data.tf에서 참조)
  vpc_security_group_ids = [local.aurora_security_group_id]
  # Aurora 엔진 설정
  engine_version = var.engine_version
  instance_class = var.instance_class
  # 데이터베이스 설정
  db_name     = var.db_name
  db_username = var.db_username
  db_port     = var.db_port
  # 백업 및 유지보수 설정
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  # 보안 설정
  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id
  # 성능 모니터링 설정
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  # AWS 관리형 비밀번호 (자동 생성 및 로테이션)
  manage_master_user_password = var.manage_master_user_password
  tags = local.common_db_tags
  # 의존성 확인 (선택적 - 디버깅용)
  depends_on = [
    # 명시적 의존성은 data.tf의 remote_state로 처리됨
  ]
}