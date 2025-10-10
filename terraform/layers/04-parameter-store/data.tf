# =============================================================================
# Data Sources - 다른 레이어의 출력값 참조
# =============================================================================
# 목적: terraform_remote_state를 통해 필요한 레이어의 출력값만 가져오기

# 03-database 레이어 상태 참조 (Aurora 엔드포인트 정보)
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/03-database/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}

# =============================================================================
# Local Values - 참조된 데이터 정리 및 검증
# =============================================================================

locals {
  # Database 레이어에서 필요한 정보
  aurora_endpoint = try(
    data.terraform_remote_state.database.outputs.cluster_endpoint,
    ""
  )

  # 의존성 검증
  database_ready = local.aurora_endpoint != "" && local.aurora_endpoint != null

  # 전체 의존성 준비 상태
  dependencies_ready = local.database_ready
}