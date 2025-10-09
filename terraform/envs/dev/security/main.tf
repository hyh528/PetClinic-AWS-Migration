# 보안 계층: IAM, 보안 그룹, VPC 엔드포인트

# 1) IAM 사용자/그룹 (프로젝트 계정)
module "iam" {
  source = "../../../modules/iam"

  project_name               = "petclinic"
  team_members               = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
  # enable_role_based_policies = false 
  # Phase 1: 모두가 AdministratorAccess, phase 2할때 각 역할별 정책 적용 후, true로 적용하면 됨.
}

# 2) 네트워크 계층 원격 상태 참조 (envs/dev/network에서 생성됨)
#    providers.tf에서 data.terraform_remote_state.network으로 선언됨

# 3) VPC 엔드포인트는 network 레이어에서 통합 관리
# 네트워크 연결성을 제공하는 리소스이므로 network 레이어에 위치

# 4) ECS 및 RDS용 보안 그룹
#    - ALB -> ECS 인그레스는 선택 사항이며 애플리케이션 계층에서 ALB SG를 사용할 수 있게 되면 활성화됨
module "security" {
  source = "../../../modules/security"

  name_prefix = "petclinic-dev"
  environment = "dev"

  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  # 애플리케이션 계층에서 ALB SG를 생성할 때까지 비워두세요 (ECS에 대한 선택적 인그레스)
  alb_security_group_id = ""

  # VPC 엔드포인트 보안 그룹은 network 레이어에서 관리
  vpce_security_group_id = data.terraform_remote_state.network.outputs.vpc_endpoint_security_group_id

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