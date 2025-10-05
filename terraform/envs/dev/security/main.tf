# terraform/envs/dev/security/main.tf

# =================================================
# 1) IAM 사용자 및 그룹 관리
# =================================================

# --- 1-1. 팀 멤버 IAM 사용자 생성 ---
# 현재: 모든 팀원에게 AdministratorAccess 권한 부여
# 향후: 역할별 세분화된 권한 정책 적용 예정
# 임시로 주석 처리 - 이미 존재하는 사용자들
# module "iam" {
#   source = "../../../modules/iam"
#
#   project_name = "petclinic"
#   team_members = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
#   # enable_role_based_policies = false  # Phase 2에서 true로 변경 예정
# }


# =================================================
# 2) 보안 그룹 (Security Groups)
# =================================================

# --- 데이터 소스: 다른 레이어의 상태 파일 읽어오기 ---
# Network 레이어에서 생성한 VPC 정보를 가져오기 위해 사용합니다.
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


# --- 보안 그룹 생성 전략 ---
# PetClinic 마이크로서비스는 4계층 아키텍처로 구성되지만, 보안 그룹은 네트워크 트래픽 흐름에 따라 설계합니다:
#
# 아키텍처 4계층:
# 1) Public Subnet: ALB, API Gateway, NAT Gateway
# 2) Private App Subnet: ECS Fargate (customers, visits, vets, admin 서비스)  
# 3) Private DB Subnet: Aurora MySQL 클러스터
# 4) AWS 관리형 서비스: Parameter Store, Secrets Manager, Lambda+Bedrock, VPC Endpoints
#
# 보안 그룹 4개 생성:
# - ALB SG: 인터넷 → ALB (HTTP/HTTPS 허용)
# - App SG: ALB → ECS 서비스 (8080 포트만 허용)  
# - DB SG: ECS 서비스 → Aurora (3306 포트만 허용)
# - VPC Endpoint SG: ECS → AWS 서비스 (HTTPS 443 포트) - 별도 보안 그룹
#
# AWS 관리형 서비스(API Gateway, Lambda 등)는 별도 보안 그룹이 불필요합니다.


# --- 2-1. ALB 보안 그룹 (Public Subnet 계층) ---
# 역할: 인터넷 사용자 → ALB 트래픽 제어
# 허용: HTTP(80), HTTPS(443) 인바운드 from 0.0.0.0/0
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
# 역할: ALB → ECS 마이크로서비스 트래픽 제어
# 허용: TCP 8080 인바운드 from ALB 보안 그룹만
# 서비스: customers, visits, vets, admin
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
# 역할: ECS 서비스 → Aurora MySQL 클러스터 트래픽 제어
# 허용: TCP 3306 인바운드 from App 보안 그룹만
# 보안: 아웃바운드 규칙 제거로 데이터 유출 방지
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
# 허용: HTTP/HTTPS 인바운드, 에페메랄 포트 아웃바운드
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
# 허용: ALB 트래픽(8080), VPC 내부 통신, NAT Gateway 아웃바운드
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
# 허용: App 서브넷에서 MySQL(3306) 트래픽만, 외부 인터넷 접근 제한
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
# 역할: ECS → AWS 서비스 (ECR, CloudWatch, SSM 등) 통신 제어
# 허용: HTTPS(443) 인바운드 from VPC CIDR
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
# 서비스: ECR, CloudWatch Logs, SSM, Secrets Manager, KMS, X-Ray
module "endpoint" {
  source = "../../../modules/endpoint"

  vpc_id                    = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids        = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
  private_route_table_ids   = values(data.terraform_remote_state.network.outputs.private_app_route_table_ids)
  vpc_endpoint_sg_id        = module.sg_vpce.security_group_id
  aws_region                = data.aws_region.current.name
  project_name              = var.name_prefix
  environment               = var.environment
}

# =================================================
# 5) Secrets Manager (민감 정보 관리)
# =================================================

# --- 5-1. DB 비밀번호 관리 ---
# Aurora MySQL 클러스터 비밀번호를 안전하게 저장
module "db_password_secret" {
  source = "../../../modules/secrets-manager"

  secret_name             = "${var.name_prefix}/dev/db-password"
  secret_description      = "데이터베이스 비밀번호"
  recovery_window_in_days = 7
  project_name            = var.name_prefix
  environment             = var.environment
  
}

# =================================================
# 6) Cognito (사용자 인증 및 권한 부여)
# =================================================

# --- 6-1. 사용자 인증 및 권한 부여 ---
# OAuth 2.0 기반 사용자 인증 시스템
module "cognito" {
  source = "../../../modules/cognito"

  project_name          = var.name_prefix
  environment           = var.environment
  cognito_callback_urls = ["http://localhost:8080/login"]
  cognito_logout_urls   = ["http://localhost:8080/logout"]
}
