# =============================================================================
# Security Layer - Data Sources
# =============================================================================
# 다른 레이어들의 출력값을 참조하여 보안 리소스 구성

# =============================================================================
# 기반 인프라 레이어 상태 참조
# =============================================================================

# 01-network 레이어 상태 참조 (VPC, 서브넷 정보)
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "${var.environment}/01-network/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# 07-application 레이어 상태 참조 (ALB 보안 그룹 정보)
# 주의: 이 레이어는 application 레이어 이후에 실행되어야 함
data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "${var.environment}/07-application/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }

  # application 레이어가 아직 배포되지 않은 경우를 대비한 에러 처리
  count = var.enable_alb_integration ? 1 : 0
}