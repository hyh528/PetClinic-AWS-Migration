# =============================================================================
# AWS Native Services Integration Layer - Data Sources
# =============================================================================
# 다른 레이어들의 출력값을 참조하여 통합 작업 수행

# =============================================================================
# 기반 인프라 레이어 상태 참조
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

# 03-database 레이어 상태 참조 (Aurora 정보)
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
# AWS 네이티브 서비스 레이어 상태 참조
# =============================================================================

# 08-api-gateway 레이어 상태 참조
data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/08-api-gateway/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}

# 04-parameter-store 레이어 상태 참조
data "terraform_remote_state" "parameter_store" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/04-parameter-store/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}

# 05-cloud-map 레이어 상태 참조
data "terraform_remote_state" "cloud_map" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/05-cloud-map/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}

# 06-lambda-genai 레이어 상태 참조
data "terraform_remote_state" "lambda_genai" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/06-lambda-genai/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}

# 07-application 레이어 상태 참조
data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket  = var.state_config.bucket_name
    key     = "${var.shared_config.environment}/07-application/terraform.tfstate"
    region  = var.state_config.region
    profile = var.state_config.profile
  }
}