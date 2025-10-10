# =============================================================================
# Data Sources - 다른 레이어의 출력값 참조
# =============================================================================
# 목적: terraform_remote_state를 통해 필요한 레이어의 출력값만 가져오기

# =============================================================================
# Remote State References - 다른 레이어의 출력값 참조
# =============================================================================

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

# 07-application 레이어 상태 참조 (ALB 보안 그룹 정보)
# 주의: 이 레이어는 application 레이어 이후에 실행되어야 함
data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/07-application/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }

  # application 레이어가 아직 배포되지 않은 경우를 대비한 에러 처리
  count = var.enable_alb_integration ? 1 : 0
}

# =============================================================================
# Local Values - 참조된 데이터 정리
# =============================================================================

locals {
  # Network 레이어에서 필요한 정보
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr = data.terraform_remote_state.network.outputs.vpc_cidr

  # Network 레이어에서 생성된 VPC 엔드포인트 보안 그룹 ID
  vpce_security_group_id = try(
    data.terraform_remote_state.network.outputs.vpce_security_group_id,
    ""
  )

  # Application 레이어에서 ALB 보안 그룹 ID (선택적)
  alb_sg_id = var.enable_alb_integration && length(data.terraform_remote_state.application) > 0 ? (
    try(data.terraform_remote_state.application[0].outputs.alb_security_group_id, "")
  ) : ""

  # 의존성 검증
  network_ready     = local.vpc_id != null && local.vpc_id != ""
  vpce_ready        = local.vpce_security_group_id != ""
  application_ready = var.enable_alb_integration ? local.alb_sg_id != "" : true

  # 전체 의존성 준비 상태
  dependencies_ready = local.network_ready && local.vpce_ready && local.application_ready
}
