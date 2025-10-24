# terraform/envs/dev/security/main.tf

# =================================================
# 1) IAM 사용자 및 그룹 관리
# =================================================
# IAM 모듈 호출
module "iam" {
  source = "../../../modules/iam"

  project_name = "petclinic"
  db_secret_arn = data.terraform_remote_state.database.outputs.db_master_user_secret_arn
  db_secret_kms_key_arn = data.terraform_remote_state.database.outputs.db_kms_key_arn
}

# API Gateway CloudWatch Logs 계정 설정
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = module.iam.api_gateway_cloudwatch_logs_role_arn
}
# =================================================
# 2) 보안 그룹 (Security Groups)
# =================================================

# --- 데이터 소스: 다른 레이어의 상태 파일 읽어오기 ---
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket         = var.tfstate_bucket_name
    key            = "dev/yeonghyeon/network/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.network_state_profile
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket         = var.tfstate_bucket_name
    key            = "dev/junje/database/terraform.tfstate" # 중요: 담당자 이름(junje)을 실제 담당자로 변경하세요.
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.database_state_profile # dev.tfvars에 정의된 프로필
  }
}


# --- 보안 그룹 생성 전략 ---
# (설명 주석 생략)

# --- 2-1. ALB 보안 그룹 (Public Subnet 계층) ---
module "sg_alb" {
  source = "../../../modules/sg"

  sg_type     = "alb"
  name_prefix = "petclinic-dev"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr

  tags = {
    Service = "ALB"
  }
}


# --- 2-2. App 보안 그룹 (Private App Subnet 계층) ---
module "sg_app" {
  source = "../../../modules/sg"

  sg_type                      = "app"
  name_prefix                  = "petclinic-dev"
  vpc_id                       = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr                     = data.terraform_remote_state.network.outputs.vpc_cidr
  alb_source_security_group_id = module.sg_alb.security_group_id

  tags = {
    Service = "Application"
  }
}


# --- 2-3. DB 보안 그룹 (Private DB Subnet 계층) ---
module "sg_db" {
  source = "../../../modules/sg"

  sg_type                      = "db"
  name_prefix                  = "petclinic-dev"
  vpc_id                       = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr                     = data.terraform_remote_state.network.outputs.vpc_cidr
  app_source_security_group_id = module.sg_app.security_group_id

  tags = {
    Service = "Database"
  }
}

# =================================================
# 3) 네트워크 ACL (Network Access Control List)
# =================================================

# --- 3-1. Public Subnet NACL ---
module "nacl_public" {
  source = "../../../modules/nacl"

  name_prefix = "public"
  environment = var.environment
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr
  nacl_type   = "public"
  subnet_ids  = values(data.terraform_remote_state.network.outputs.public_subnet_ids)
}

# --- 3-2. Private App Subnet NACL ---
module "nacl_private_app" {
  source = "../../../modules/nacl"

  name_prefix = "private-app"
  environment = var.environment
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr
  nacl_type   = "private-app"
  subnet_ids  = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
}

# --- 3-3. Private DB Subnet NACL ---
module "nacl_private_db" {
  source = "../../../modules/nacl"

  name_prefix = "private-db"
  environment = var.environment
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr
  nacl_type   = "private-db"
  subnet_ids  = values(data.terraform_remote_state.network.outputs.private_db_subnet_ids)
}

# =================================================
# 4) VPC 엔드포인트 (VPC Endpoints)
# =================================================

# --- 4-1. VPC Endpoint 보안 그룹 ---
data "aws_region" "current" {}

module "sg_vpce" {
  source = "../../../modules/sg"

  sg_type     = "vpce"
  name_prefix = var.name_prefix
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr

  tags = {
    Service = "VPCE"
  }
}

# --- 4-2. VPC Endpoints 생성 ---
module "endpoint" {
  source = "../../../modules/endpoint"

  vpc_id                    = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids        = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
  private_route_table_ids   = values(data.terraform_remote_state.network.outputs.private_app_route_table_ids)
  vpc_endpoint_sg_id        = module.sg_vpce.security_group_id
  aws_region                = data.aws_region.current.id
  project_name              = var.name_prefix
  environment               = var.environment
}

# =================================================
# 5) Cognito (사용자 인증 및 권한 부여)
# =================================================

# --- 5-1. 사용자 인증 및 권한 부여 ---
module "cognito" {
  source = "../../../modules/cognito"

  project_name          = var.name_prefix
  environment           = var.environment
  cognito_callback_urls = ["http://localhost:8080/login"]
  cognito_logout_urls   = ["http://localhost:8080/logout"]
}
