# 보안 계층: IAM, 보안 그룹, VPC 엔드포인트

# 1) IAM 사용자/그룹 (프로젝트 계정)
module "iam" {
  source = "../../../modules/iam"

  project_name               = "petclinic"
  team_members               = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
  enable_role_based_policies = false # Phase 1: AdministratorAccess
}

# 2) 네트워크 계층 원격 상태 참조 (envs/dev/network에서 생성됨)
#    providers.tf에서 data.terraform_remote_state.network으로 선언됨

# 3) VPC 엔드포인트 (S3 게이트웨이 + 인터페이스 엔드포인트)
module "endpoints" {
  source = "../../../modules/endpoints"

  name_prefix = "petclinic-dev"
  environment = "dev"

  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr = data.terraform_remote_state.network.outputs.vpc_cidr

  interface_subnet_ids = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)

  public_route_table_id       = data.terraform_remote_state.network.outputs.public_route_table_id
  private_app_route_table_ids = data.terraform_remote_state.network.outputs.private_app_route_table_ids
  private_db_route_table_ids  = data.terraform_remote_state.network.outputs.private_db_route_table_ids

  # modules/endpoints/variables.tf에서 인터페이스 서비스를 사용자 정의할 수 있습니다
  # create_interface_endpoints = true

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "security"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# 4) ECS 및 RDS용 보안 그룹
#    - ALB -> ECS 인그레스는 선택 사항이며 애플리케이션 계층에서 ALB SG를 사용할 수 있게 되면 활성화됨
module "security" {
  source = "../../../modules/security"

  name_prefix = "petclinic-dev"
  environment = "dev"

  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  # 애플리케이션 계층에서 ALB SG를 생성할 때까지 비워두세요 (ECS에 대한 선택적 인그레스)
  alb_security_group_id = ""

  # 인터페이스 엔드포인트로의 송신을 선호 (HTTPS 443), 비어 있으면 인터넷으로 폴백
  vpce_security_group_id = module.endpoints.vpce_security_group_id

  # ecs_task_port = 8080
  # rds_port      = 3306

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "security"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}