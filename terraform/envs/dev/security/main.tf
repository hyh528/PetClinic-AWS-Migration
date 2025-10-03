# terraform/envs/dev/security/main.tf

# =================================================
# 1) IAM 사용자/그룹 (프로젝트 계정)
# =================================================
module "iam" {
  source = "../../../modules/iam"

  project_name               = "petclinic"
  team_members               = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
  # enable_role_based_policies = false 
  # Phase 1: 모두가 AdministratorAccess, phase 2할때 각 역할별 정책 적용 후, true로 적용하면 됨.
}


# =================================================
# 2) 보안 그룹 (Security Groups)
# =================================================

# --- 데이터 소스: 다른 레이어의 상태 파일 읽어오기 ---
# data "terraform_remote_state" 블록은 다른 디렉토리에서 실행된 Terraform의
# 상태 파일(terraform.tfstate)을 읽어와서 그 안의 출력(outputs) 값을 사용할 수 있게 해줍니다.
# 여기서는 'network' 레이어에서 생성한 VPC의 정보를 가져오기 위해 사용합니다.
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = "petclinic-tfstate-team-jungsu-kopo"
    key     = "dev/yeonghyeon/network/terraform.tfstate" 
    region  = "ap-northeast-2"
    profile = var.network_state_profile # 변경 이유: 'profile' 인자를 하드코딩된 값 대신 'var.network_state_profile' 변수로 변경하여 환경별 프로필 설정을 유연하게 관리하고, 'terraform plan' 실행 시 발생했던 'failed to get shared config profile' 에러를 해결합니다。
  }
}


# --- 보안 그룹 생성: 모듈을 여러 번 호출하는 이유 ---
# 우리 애플리케이션은 ALB, App, DB 라는 3개의 주요 계층(Tier)으로 구성됩니다.
# 각 계층은 서로 다른 보안 규칙을 가져야 합니다. (예: ALB는 외부 인터넷에, DB는 App에만 열려 있어야 함)
# 따라서, 각 계층에 맞는 보안 그룹을 각각 하나씩, 총 3개 생성해야 합니다.
# 'sg' 모듈은 "보안 그룹을 만드는 공장"과 같습니다. 이 공장에 "ALB용 주문서", "App용 주문서", "DB용 주문서"를
# 각각 넣어주어, 각기 다른 사양의 보안 그룹 제품을 3개 만들어내는 것입니다.
# 이것이 모듈을 여러 번 호출하는 이유이며, Terraform에서 권장하는 올바른 설계 방식입니다。


# --- 2-1. ALB 보안 그룹 생성 ---
module "sg_alb" {
  # 사용할 모듈의 경로를 지정합니다.
  source = "../../../modules/sg"

  # 'sg' 모듈의 variables.tf에 정의된 변수들에게 값을 전달합니다.
  sg_type     = "alb"             # "alb" 타입의 보안 그룹을 생성하도록 지정
  name_prefix = "petclinic-dev"   # 생성될 리소스의 이름 접두사
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id # network 레이어에서 가져온 VPC ID
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr # 변경 이유: 'sg' 모듈의 'vpc_cidr' 변수가 추가됨에 따라, network 레이어에서 가져온 VPC CIDR 값을 전달합니다. 이는 'terraform plan' 실행 시 발생했던 'Missing required argument: vpc_cidr' 에러를 해결합니다。
  
  # 추가적인 태그를 지정합니다.
  tags = {
    Service = "ALB"
  }
}


# --- 2-2. App (ECS) 보안 그룹 생성 ---
module "sg_app" {
  source = "../../../modules/sg"

  sg_type     = "app"             # "app" 타입의 보안 그룹을 생성하도록 지정
  name_prefix = "petclinic-dev"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr # 변경 이유: 'sg' 모듈의 'vpc_cidr' 변수가 추가됨에 따라, network 레이어에서 가져온 VPC CIDR 값을 전달합니다. 이는 'terraform plan' 실행 시 발생했던 'Missing required argument: vpc_cidr' 에러를 해결합니다。
  
  # App 보안 그룹은 ALB로부터의 트래픽을 받아야 합니다.
  # 따라서, 'sg' 모듈의 'alb_source_security_group_id' 변수에
  # 위에서 만든 ALB 보안 그룹의 ID (module.sg_alb.security_group_id)를 전달해줍니다.
alb_source_security_group_id = module.sg_alb.security_group_id

  tags = {
    Service = "Application"
  }
}


# --- 2-3. DB (Aurora) 보안 그룹 생성 ---
module "sg_db" {
  source = "../../../modules/sg"

  sg_type     = "db"              # "db" 타입의 보안 그룹을 생성하도록 지정
  name_prefix = "petclinic-dev"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr # 변경 이유: 'sg' 모듈의 'vpc_cidr' 변수가 추가됨에 따라, network 레이어에서 가져온 VPC CIDR 값을 전달합니다. 이는 'terraform plan' 실행 시 발생했던 'Missing required argument: vpc_cidr' 에러를 해결합니다。

  # DB 보안 그룹은 App으로부터의 트래픽을 받아야 합니다.
  # 'app_source_security_group_id' 변수에
  # 위에서 만든 App 보안 그룹의 ID (module.sg_app.security_group_id)를 전달해줍니다。
  app_source_security_group_id = module.sg_app.security_group_id

  tags = {
    Service = "Database"
  }
}

# =================================================
# 3) 네트워크 ACL (Network Access Control List)
# =================================================

# --- 3-1. Public Subnet용 NACL 생성 ---
# Public Subnet은 외부 인터넷과 직접 통신하므로, HTTP/HTTPS 트래픽을 허용하고
# 응답 트래픽을 위한 임시 포트 범위를 허용하는 규칙이 필요합니다.
module "nacl_public" {
  source = "../../../modules/nacl" # NACL 모듈 경로

  name_prefix = "public" # NACL 이름 접두사
  environment = var.environment # 환경 변수 (dev, prod 등)
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id # network 레이어에서 가져온 VPC ID
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr # NACL 모듈 내부에서 사용할 VPC CIDR
  nacl_type   = "public" # Public Subnet용 NACL임을 지정

  # Public Subnet ID 목록을 전달합니다.
  # network 레이어의 public_subnet_ids는 맵 형태이므로 values() 함수로 값만 추출합니다.
  subnet_ids = values(data.terraform_remote_state.network.outputs.public_subnet_ids)
}

# --- 3-2. Private App Subnet용 NACL 생성 ---
# Private App Subnet은 ALB로부터의 트래픽과 VPC 내부 서비스(DB, VPC Endpoint)와의 통신을 허용합니다.
# 외부 인터넷으로는 NAT Gateway를 통해 나갑니다.
module "nacl_private_app" {
  source = "../../../modules/nacl"

  name_prefix = "private-app"
  environment = var.environment
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr
  nacl_type   = "private-app" # Private App Subnet용 NACL임을 지정

  # Private App Subnet ID 목록을 전달합니다.
  subnet_ids = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
}

# --- 3-3. Private DB Subnet용 NACL 생성 ---
# Private DB Subnet은 Private App Subnet으로부터의 DB 트래픽만 허용하고,
# VPC 내부 통신 및 응답 트래픽을 허용합니다. 외부 인터넷 접근은 제한됩니다.
module "nacl_private_db" {
  source = "../../../modules/nacl"

  name_prefix = "private-db"
  environment = var.environment
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr
  nacl_type   = "private-db" # Private DB Subnet용 NACL임을 지정

  # Private DB Subnet ID 목록을 전달합니다.
  subnet_ids = values(data.terraform_remote_state.network.outputs.private_db_subnet_ids)
}

# =================================================
# 4) VPC 엔드포인트 (VPC Endpoints)
# =================================================

# --- 현재 AWS 리전 정보 가져오기 ---
data "aws_region" "current" {}

# --- VPC 엔드포인트 보안 그룹 생성 ---
# VPC 엔드포인트는 특정 포트를 통해 AWS 서비스와 통신하므로,
# 이 통신을 허용하는 보안 그룹이 필요합니다.
module "sg_vpce" {
  source = "../../../modules/sg"

  sg_type     = "vpce" # "vpce" 타입의 보안 그룹을 생성하도록 지정
  name_prefix = var.name_prefix # 기존 name_prefix 변수 사용
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr # 변경 이유: 'sg' 모듈의 'vpc_cidr' 변수가 추가됨에 따라, network 레이어에서 가져온 VPC CIDR 값을 전달합니다. 이는 'terraform plan' 실행 시 발생했던 'Missing required argument: vpc_cidr' 에러를 해결합니다。

  tags = {
    Service = "VPCE"
  }
}

# --- VPC 엔드포인트 모듈 호출 ---
# 프라이빗 서브넷에서 AWS 서비스에 안전하게 접근하기 위한 VPC 엔드포인트를 생성합니다.
module "endpoint" {
  source = "../../../modules/endpoint"

  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids   = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
  vpc_endpoint_sg_id   = module.sg_vpce.security_group_id
  aws_region           = data.aws_region.current.name
  project_name         = var.name_prefix # name_prefix를 project_name으로 전달
  environment          = var.environment
}

# =================================================
# 5) Secrets Manager (민감 정보 관리)
# =================================================

# --- DB 비밀번호를 위한 Secrets Manager 시크릿 생성 ---
# 데이터베이스 비밀번호와 같은 민감 정보를 안전하게 저장하고 관리합니다.
# 실제 비밀번호 값은 Terraform 코드에 직접 노출하지 않고, AWS 콘솔이나 다른 방법으로 설정합니다.
module "db_password_secret" {
  source = "../../../modules/secrets-manager"

  secret_name             = "${var.name_prefix}/dev/db-password" # 시크릿 이름: petclinic/dev/db-password
  secret_description      = "Database password for PetClinic application"
  recovery_window_in_days = 7 # 7일 후 영구 삭제 (기본 30일에서 변경)
  project_name            = var.name_prefix
  environment             = var.environment
}

# =================================================
# 6) Cognito (사용자 인증 및 권한 부여)
# =================================================

# --- Cognito User Pool 및 클라이언트 생성 ---
# 웹 및 모바일 앱에 사용자 가입, 로그인 및 액세스 제어를 제공합니다.
module "cognito" {
  source = "../../../modules/cognito"

  project_name        = var.name_prefix
  environment         = var.environment
  # 콜백 및 로그아웃 URL은 애플리케이션의 URL에 따라 달라집니다.
  # 현재는 개발용 기본값을 사용하며, 나중에 실제 URL로 업데이트해야 합니다.
  cognito_callback_urls = ["http://localhost:8080/login"] # 예시: 애플리케이션의 로그인 후 리다이렉트 URL
  cognito_logout_urls   = ["http://localhost:8080/logout"] # 예시: 애플리케이션의 로그아웃 후 리다이렉트 URL
}