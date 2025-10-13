# =============================================================================
# API Gateway Layer - Spring Cloud Gateway 대체(AWS 네이티브 서비스)
# =============================================================================
# 목적: 단일 책임 원칙 적용 - API Gateway 관리만 담당
# 의존성: 01-network, 02-security, 07-application 레이어
# 개선사항: 공유 변수 서비스 적용, 표준화된 상태 참조

# 공통 로컬 변수(공유 변수 서비스 기반)
locals {
  # Application 레이어에서 필요한 정보
  alb_dns_name = data.terraform_remote_state.application.outputs.alb_dns_name

  # GenAI Lambda 함수 정보 (06-lambda-genai 레이어에서 참조)
  lambda_function_invoke_arn = data.terraform_remote_state.lambda_genai.outputs.lambda_function_invoke_arn

  # API Gateway 공통 설정
  layer_common_tags = merge(var.tags, {
    Layer     = "08-api-gateway"
    Component = "api-gateway"
    Purpose   = "spring-cloud-gateway-replacement"
  })
}

# =============================================================================
# Data Sources - 표준화된 원격 상태 참조
# =============================================================================

# =============================================================================
# API Gateway 모듈 (Spring Cloud Gateway 대체)
# =============================================================================
module "api_gateway" {
  source = "../../modules/api-gateway"

  # 기본 설정
  name_prefix = var.name_prefix
  environment = var.environment
  stage_name  = var.stage_name

  # ALB 통합 설정 (application 레이어에서 참조)
  alb_dns_name = local.alb_dns_name

  # Lambda 통합 설정 (GenAI 서비스용)
  enable_lambda_integration     = true
  lambda_function_invoke_arn    = local.lambda_function_invoke_arn
  lambda_integration_timeout_ms = var.lambda_integration_timeout_ms

  # 스로틀링 설정
  throttle_rate_limit  = var.throttle_rate_limit
  throttle_burst_limit = var.throttle_burst_limit

  # 통합 설정
  integration_timeout_ms = var.integration_timeout_ms

  # 로깅 및 추적 (임시로 로깅 비활성화)
  log_retention_days  = var.log_retention_days
  enable_xray_tracing = false # X-Ray 추적도 임시 비활성화

  # CORS 설정
  enable_cors = var.enable_cors

  # 사용량 계획
  create_usage_plan = var.create_usage_plan

  # 모니터링 설정
  enable_monitoring = var.enable_monitoring
  create_dashboard  = var.create_dashboard
  alarm_actions     = var.alarm_actions

  # 임계값 설정
  error_4xx_threshold           = var.error_4xx_threshold
  error_5xx_threshold           = var.error_5xx_threshold
  latency_threshold             = var.latency_threshold
  integration_latency_threshold = var.integration_latency_threshold

  tags = local.layer_common_tags
}