# =============================================================================
# API Gateway Layer - Data Sources
# =============================================================================
# 다른 레이어들의 출력값을 참조하여 API Gateway 구성

# =============================================================================
# 기반 인프라 레이어 상태 참조
# =============================================================================

# 01-network 레이어 상태 참조 (VPC 정보)
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

# 07-application 레이어 상태 참조 (ALB 정보)
data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/07-application/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}