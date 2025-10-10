# =============================================================================
# Data Sources - 다른 레이어의 출력값 참조
# =============================================================================
# 목적: terraform_remote_state를 통해 필요한 레이어의 출력값만 가져오기

# 01-network 레이어 상태 참조 (VPC, 서브넷 정보)
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/01-network/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}

# 02-security 레이어 상태 참조 (보안 그룹 정보)
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/02-security/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}

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

  # =============================================================================
  # 의존성 검증 로직
  # =============================================================================

  # Network 레이어 준비 상태 검증
  network_ready = (
    length(local.private_db_subnet_ids) >= 2 && # 최소 2개 서브넷 필요 (Multi-AZ)
    local.vpc_id != null &&
    local.vpc_id != ""
  )

  # Security 레이어 준비 상태 검증
  security_ready = (
    local.aurora_security_group_id != null &&
    local.aurora_security_group_id != "" &&
    can(regex("^sg-[a-f0-9]+$", local.aurora_security_group_id)) # 보안 그룹 ID 형식 검증
  )

  # 전체 의존성 준비 상태
  dependencies_ready = local.network_ready && local.security_ready

  # =============================================================================
  # 디버깅 정보 (개발 시 유용)
  # =============================================================================

  debug_info = {
    network_outputs_available  = length(keys(try(data.terraform_remote_state.network.outputs, {})))
    security_outputs_available = length(keys(try(data.terraform_remote_state.security.outputs, {})))
    subnet_count               = length(local.private_db_subnet_ids)
    vpc_id_present             = local.vpc_id != null
    security_group_valid       = local.security_ready
  }
}

# =============================================================================
# 의존성 검증 (로컬 값으로만 처리)
# =============================================================================
# 
# 주의: 레이어에서는 리소스를 직접 생성하지 않습니다.
# 의존성 검증은 locals와 outputs를 통해서만 수행합니다.
# 실제 검증은 terraform plan/apply 시 출력값을 통해 확인할 수 있습니다.

# =============================================================================
# Note: DB 비밀번호는 Aurora 모듈에서 manage_master_user_password = true로 자동 관리
# AWS Secrets Manager를 통해 자동 생성 및 로테이션됨
# =============================================================================