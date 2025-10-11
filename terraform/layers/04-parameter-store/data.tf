# =============================================================================
# Parameter Store Layer - Data Sources
# =============================================================================
# 다른 레이어들의 출력값을 참조하여 Parameter Store 구성

# =============================================================================
# 기반 인프라 레이어 상태 참조
# =============================================================================

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