# ==========================================
# DB Password Secret 참조 (Database 레이어에서 관리)
# ==========================================
# 아키텍처 개선: 시크릿은 Database 레이어에서 중앙 관리
# Application 레이어는 Database 레이어의 출력을 참조

# Database 레이어의 remote state 참조
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/junje/database/terraform.tfstate"
    region  = var.aws_region
    profile = var.database_state_profile
  }
}

# Database 레이어에서 관리하는 시크릿 참조
data "aws_secretsmanager_secret_version" "db_password" {
  # Database 레이어의 시크릿 ARN을 통해 참조
  secret_id = data.terraform_remote_state.database.outputs.db_password_secret_arn

  # depends_on으로 명시적 의존성 설정
  depends_on = [data.terraform_remote_state.database]
}