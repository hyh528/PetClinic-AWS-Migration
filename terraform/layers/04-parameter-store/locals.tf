# =============================================================================
# Parameter Store Layer - 로컬 값 정의
# =============================================================================
# 목적: Parameter Store 구성에 필요한 로컬 값들을 정의

locals {
  # Database 레이어에서 필요한 정보
  aurora_endpoint = try(
    data.terraform_remote_state.database.outputs.cluster_endpoint,
    ""
  )

  # 의존성 검증
  database_ready     = local.aurora_endpoint != "" && local.aurora_endpoint != null
  dependencies_ready = local.database_ready

  # Parameter Store 공통 설정
  common_parameter_tags = merge(var.tags, {
    Layer     = "04-parameter-store"
    Component = "parameter-store"
    Purpose   = "spring-config-replacement"
  })

  # 기본 공통 설정만 우선
  basic_parameters = {
    # Spring 프로파일 설정
    "/petclinic/common/spring.profiles.active" = "mysql,aws"
    "/petclinic/common/logging.level.root"     = "INFO"
    # 서버 포트 설정 (각 서비스별 실제 포트)
    "/petclinic/${var.environment}/customers/server.port" = "8081"
    "/petclinic/${var.environment}/vets/server.port"      = "8082"
    "/petclinic/${var.environment}/visits/server.port"    = "8083"
    "/petclinic/${var.environment}/admin/server.port"     = "8080"
  }

  # 데이터베이스 연결 정보 (data.tf에서 참조)
  database_parameters = local.dependencies_ready ? {
    # 공통 데이터베이스 파라미터 (모든 서비스가 공유)
    "/petclinic/${var.environment}/db/url"      = "jdbc:mysql://${local.aurora_endpoint}:3306/petclinic?useSSL=false&allowPublicKeyRetrieval=true"
    "/petclinic/${var.environment}/db/username" = var.database_username
    # Secret ARN은 일반 String 파라미터로 저장 (SecureString이 아님)
    "/petclinic/${var.environment}/db/secrets-manager-name" = data.terraform_remote_state.database.outputs.master_user_secret_name
  } : {}

  # 민감한 정보 암호화 설정 (SecureString) - 실제 비밀번호 값만
  secure_parameters = {}
}