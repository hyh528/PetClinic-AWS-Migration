# =============================================================================
# Frontend Hosting Layer - Data Sources
# =============================================================================
# 다른 레이어들의 출력값을 참조하여 프론트엔드 호스팅 구성

# =============================================================================
# 기반 인프라 레이어 상태 참조
# =============================================================================

# 08-api-gateway 레이어 상태 참조 (API Gateway 정보)
data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "seoul-dev/08-api-gateway/terraform.tfstate"
    region = var.aws_region
  }
}