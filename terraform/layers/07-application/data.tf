# =============================================================================
# Data Sources - 원격 상태 참조
# =============================================================================

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/01-network/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/02-security/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/03-database/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}