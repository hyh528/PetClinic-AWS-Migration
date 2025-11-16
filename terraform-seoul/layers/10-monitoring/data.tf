# =============================================================================
# Monitoring Layer - Data Sources
# =============================================================================
# 다른 레이어들의 출력값을 참조하여 모니터링 구성

# =============================================================================
# 기반 인프라 레이어 상태 참조
# =============================================================================

# 01-network 레이어 상태 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "seoul-dev/01-network/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# 02-security 레이어 상태 참조
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "seoul-dev/02-security/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# 03-database 레이어 상태 참조
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "seoul-dev/03-database/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# 07-application 레이어 상태 참조
data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "seoul-dev/07-application/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# 09-aws-native 레이어 상태 참조 (필수)
data "terraform_remote_state" "aws_native" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "seoul-dev/09-aws-native/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}