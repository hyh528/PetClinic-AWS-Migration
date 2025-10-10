# =============================================================================
# Parameter Store Layer - Spring Cloud Config Server 대체
# =============================================================================
# 목적: AWS Well-Architected 원칙에 따른 중앙화된 설정 관리
# 의존성: 03-database 레이어 (Aurora 엔드포인트)

# 공통 로컬 변수
locals {
  # Parameter Store 공통 설정 (공유 변수 시스템 사용)
  common_parameter_tags = merge(var.shared_config.common_tags, {
    Layer     = "04-parameter-store"
    Component = "parameter-store"
    Purpose   = "spring-config-replacement"
  })

  # 의존성 검증은 data.tf에서 정의됨
}

# =============================================================================
# 단순화된 Parameter Store 설정 (기본 파라미터만 유지)
# =============================================================================

locals {
  # 기본 공통 설정만 유지
  basic_parameters = {
    # Spring 프로파일 설정
    "/petclinic/common/spring.profiles.active" = "mysql,aws"
    "/petclinic/common/logging.level.root"     = "INFO"

    # 서버 포트 설정
    "/petclinic/${var.shared_config.environment}/customers/server.port" = "8080"
    "/petclinic/${var.shared_config.environment}/vets/server.port"      = "8080"
    "/petclinic/${var.shared_config.environment}/visits/server.port"    = "8080"
    "/petclinic/${var.shared_config.environment}/admin/server.port"     = "9090"
  }

  # 데이터베이스 연결 정보 (data.tf에서 참조)
  database_parameters = local.dependencies_ready ? {
    "/petclinic/${var.shared_config.environment}/customers/database.url"      = "jdbc:mysql://${local.aurora_endpoint}:3306/petclinic_customers"
    "/petclinic/${var.shared_config.environment}/customers/database.username" = var.database_username
    "/petclinic/${var.shared_config.environment}/vets/database.url"           = "jdbc:mysql://${local.aurora_endpoint}:3306/petclinic_vets"
    "/petclinic/${var.shared_config.environment}/vets/database.username"      = var.database_username
    "/petclinic/${var.shared_config.environment}/visits/database.url"         = "jdbc:mysql://${local.aurora_endpoint}:3306/petclinic_visits"
    "/petclinic/${var.shared_config.environment}/visits/database.username"    = var.database_username
  } : {}
}

# =============================================================================
# Parameter Store 모듈 (단순화)
# =============================================================================

module "parameter_store" {
  source = "../../modules/parameter-store"

  # 기본 설정 (공유 변수 시스템 사용)
  name_prefix      = var.shared_config.name_prefix
  environment      = var.shared_config.environment
  parameter_prefix = var.parameter_prefix

  # 단순화된 파라미터 설정 (모듈 변수명에 맞춤)
  common_parameters      = local.basic_parameters
  environment_parameters = locaatabase_parameters

  # 기본 태그 설정
  tags = local.common_parameter_tags

  # 의존성 확인 (선택적 - 디버깅용)
  depends_on = [
    # 명시적 의존성은 data.tf의 remote_state로 처리됨
  ]
}