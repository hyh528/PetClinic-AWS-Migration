# /terraform/envs/dev/database/main.tf

# ===================================================================
# Application Configuration (SSM Parameter Store & Secrets Manager)
# ===================================================================
module "config" {
  source = "../../../modules/config"

  project_name = var.project_name
  environment  = var.environment

  # 1단계: 정해진 값으로 먼저 파라미터를 생성합니다.
  # 실제 DB 생성 후 db_endpoint 값은 실제 DB의 정보로 대체될 예정입니다.
  db_username = "petclinic"
  db_password = "KOPOpetclini@#"
  db_endpoint = "please-run-terraform-apply-to-update.rds.amazonaws.com"
  db_name     = var.db_name
}
