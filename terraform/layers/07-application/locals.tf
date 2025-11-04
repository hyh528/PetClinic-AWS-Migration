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
  ecs_security_group_id             = data.terraform_remote_state.security.outputs.ecs_security_group_id
  aurora_security_group_id          = data.terraform_remote_state.security.outputs.aurora_security_group_id
  rds_secret_access_policy_arn      = data.terraform_remote_state.security.outputs.rds_secret_access_policy_arn
  parameter_store_access_policy_arn = data.terraform_remote_state.security.outputs.parameter_store_access_policy_arn
  # ecs_task_execution_role_arn       = data.terraform_remote_state.security.outputs.ecs_task_execution_role_arn

  # Database 레이어에서 필요한 정보 (하드코딩 제거)
  db_secret_arn = data.terraform_remote_state.database.outputs.master_user_secret_name

  # 환경별 설정
  log_retention_days = var.environment == "prod" ? 90 : 30

  # 공통 환경 변수
  common_environment = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "mysql,aws"
    },
    {
      name  = "AWS_REGION"
      value = var.aws_region
    },
    {
      name  = "AWS_ECR_DEBUG"
      value = "true"
    }
  ]

  # 공통 시크릿 설정 (동적 참조 사용) - Admin 서버 제외
  common_secrets = [
    {
      name      = "SPRING_DATASOURCE_URL"
      valueFrom = "/petclinic/${var.environment}/db/url"
    },
    {
      name      = "SPRING_DATASOURCE_USERNAME"
      valueFrom = "/petclinic/${var.environment}/db/username"
    },
    {
      name      = "SPRING_DATASOURCE_PASSWORD"
      valueFrom = "${local.db_secret_arn}:password::"
    }
  ]

  # Admin 서버용 빈 시크릿 (DB 연결 불필요)
  admin_secrets = []

  # Admin 서버용 환경 변수 (ALB DNS 이름 포함)
  admin_environment = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "aws"
    },
    {
      name  = "AWS_REGION"
      value = var.aws_region
    },
    {
      name  = "ALB_DNS_NAME"
      value = module.alb.alb_dns_name
    }
  ]

  # 공통 태그
  layer_common_tags = merge(var.tags, {
    Layer     = "07-application"
    Component = "application-infrastructure"
  })

  # 서비스 정의 (환경별 설정 가능)
  services = {
    customers = {
      name        = "customers-service"
      port        = 8080
      health_path = "/actuator/health"
      cpu         = 256
      memory      = 512
    }
    vets = {
      name        = "vets-service"
      port        = 8080
      health_path = "/actuator/health"
      cpu         = 256
      memory      = 512
    }
    visits = {
      name        = "visits-service"
      port        = 8080
      health_path = "/actuator/health"
      cpu         = 256
      memory      = 512
    }
    admin = {
      name        = "admin-server"
      port        = 9090
      health_path = "/admin/actuator/health"
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