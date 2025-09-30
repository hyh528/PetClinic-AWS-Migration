# ==========================================
# Database 레이어: Aurora MySQL 클러스터
# ==========================================
# 준제(junje)가 담당하는 Database 인프라
# 재사용 가능한 database 모듈을 사용하여 Aurora 클러스터 생성

module "database" {
  source = "../../../modules/database"

  name_prefix = var.name_prefix

  private_db_subnet_ids  = var.private_db_subnet_ids
  vpc_security_group_ids = [data.terraform_remote_state.security.outputs.rds_security_group_id]

  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  db_port     = var.db_port

  backup_retention_period = var.backup_retention_period

  tags = var.tags
}

# ==========================================
# 생성 후 사용법:
# ==========================================
# 1. terraform apply 실행
# 2. terraform output으로 엔드포인트 확인