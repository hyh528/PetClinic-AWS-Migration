# ==========================================
# Database 레이어: RDS MySQL
# ==========================================
# 준제(junje)가 담당하는 Database 인프라
# 재사용 가능한 Database 모듈을 호출

module "database" {
  source = "../../../modules/database"

  name_prefix = var.name_prefix
  private_db_subnet_ids = var.private_db_subnet_ids
  vpc_security_group_ids = [data.terraform_remote_state.security.outputs.rds_security_group_id]

  # Database 설정
  db_password = var.db_password  # 실제로는 AWS Secrets Manager 사용 권장

  tags = var.tags
}