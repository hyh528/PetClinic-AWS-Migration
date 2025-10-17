# =============================================================================
# Application Layer - 로컬 값 정의
# =============================================================================
# 목적: 애플리케이션 인프라 구성에 필요한 로컬 값들을 정의

locals {
  # Network 레이어에서 필요한 정보
  vpc_id                 = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids      = values(data.terraform_remote_state.network.outputs.public_subnet_ids)
  private_app_subnet_ids = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)

  # Security 레이어에서 필요한 정보
  ecs_security_group_id = data.terraform_remote_state.security.outputs.ecs_security_group_id

  # 공통 태그
  layer_common_tags = merge(var.tags, {
    Layer     = "07-application"
    Component = "application-infrastructure"
  })

  # 서비스 정의 (환경별 설정 가능)
  services = {
    customers = {
      name        = "customers-service"
      port        = 8081
      health_path = "/actuator/health"
      cpu         = 256
      memory      = 512
    }
    vets = {
      name        = "vets-service"
      port        = 8082
      health_path = "/actuator/health"
      cpu         = 256
      memory      = 512
    }
    visits = {
      name        = "visits-service"
      port        = 8083
      health_path = "/actuator/health"
      cpu         = 256
      memory      = 512
    }
    admin = {
      name        = "admin-server"
      port        = 9090
      health_path = "/actuator/health"
      cpu         = 256
      memory      = 512
    }
  }

  # 서비스별 디렉토리 매핑 (실제 디렉토리 이름과 매핑)
  service_directories = {
    customers = "customers-service"
    vets      = "vets-service"
    visits    = "visits-service"
    admin     = "admin-server"
  }
}