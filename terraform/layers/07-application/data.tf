# =============================================================================
# Data Sources - 원격 상태 참조
# =============================================================================

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "${var.environment}/01-network/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "${var.environment}/02-security/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "${var.environment}/03-database/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}