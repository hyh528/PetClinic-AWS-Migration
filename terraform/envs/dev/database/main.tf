# /terraform/envs/dev/database/main.tf

# ===================================================================
# Application Configuration (SSM Parameter Store & Secrets Manager)
# ===================================================================
module "config" {
  source = "../../../modules/config"

  project_name = var.project_name
  environment  = var.environment

  # DB 모듈에서 생성될 정보들을 전달받게 됩니다.
  db_username = var.db_master_username
  db_password = var.db_master_password
  # db_endpoint = module.aurora_db.cluster_endpoint # Aurora DB 생성 후 연결
  db_name     = var.db_name
}
