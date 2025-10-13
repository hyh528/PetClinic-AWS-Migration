# =============================================================================
# Cloud Map Layer - Data Sources
# =============================================================================
# 다른 레이어들의 출력값을 참조하여 Cloud Map 구성

# =============================================================================
# 기반 인프라 레이어 상태 참조
# =============================================================================

# 01-network 레이어 상태 참조 (VPC ID)
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "${var.environment}/01-network/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}