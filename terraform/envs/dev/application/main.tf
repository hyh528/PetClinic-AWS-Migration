# 애플리케이션 계층: ALB (나중에 ECS 등)

# ALB는 네트워크 계층 VPC와 퍼블릭 서브넷에 의존합니다
# 네트워크 원격 상태는 providers.tf에서 data.terraform_remote_state.network으로 구성됩니다

module "alb" {
  source = "../../../modules/alb"

  name_prefix = "petclinic-dev"
  environment = "dev"

  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids = values(data.terraform_remote_state.network.outputs.public_subnet_ids)

  # HTTPS는 선택 사항입니다; 처음에는 HTTP 전용으로 실행하려면 비워두세요
  certificate_arn = ""

  # 보안 그룹 인그레스 제어
  allow_ingress_cidrs_ipv4 = ["0.0.0.0/0"]
  allow_ingress_ipv6_any   = true

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "application"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# 나중에: ECS (클러스터, 서비스, 태스크 정의)는 module.alb.default_target_group_arn에 연결할 수 있습니다