# =============================================================================
# Parameter Store Layer - Spring Cloud Config Server 대체
# =============================================================================
# 목적: AWS Well-Architected 원칙에 따른 중앙화된 설정 관리
# 의존성: 03-database 레이어(Aurora 엔드포인트)

# =============================================================================
# Parameter Store 모듈 (애플리케이션용)
# =============================================================================
module "parameter_store" {
  source = "../../modules/parameter-store"
  # 기본 설정
  name_prefix      = var.name_prefix
  environment      = var.environment
  parameter_prefix = var.parameter_prefix
  # 애플리케이션 파라미터 설정 (모듈 변수명에 맞춤)
  common_parameters      = local.basic_parameters
  environment_parameters = local.database_parameters
  # secure_parameters는 locals.tf에 정의되어 있음
  secure_parameters = local.secure_parameters
  # 기본 태그 설정
  tags = local.common_parameter_tags
  # 의존성 확인 (선택적 - 디버깅용)
  depends_on = [
    # 명시적 의존성은 data.tf의 remote_state로 처리됨
  ]
}