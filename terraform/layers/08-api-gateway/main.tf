# API Gateway 레이어 - Spring Cloud Gateway 대체
# 단일 책임: API Gateway 관리만 담당

# 기존 레이어들의 원격 상태 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/yeonghyeon/network/terraform.tfstate"
    region  = var.aws_region
    profile = var.network_state_profile
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/hwigwon/security/terraform.tfstate"
    region  = var.aws_region
    profile = var.security_state_profile
  }
}

data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/seokgyeom/application/terraform.tfstate"
    region  = var.aws_region
    profile = var.application_state_profile
  }
}

# API Gateway 모듈 (Spring Cloud Gateway 대체)
module "api_gateway" {
  source = "../../../modules/api-gateway"

  name_prefix = var.name_prefix
  environment = var.environment
  stage_name  = var.stage_name

  # ALB DNS 이름 (application 레이어에서 가져옴)
  alb_dns_name = data.terraform_remote_state.application.outputs.alb_dns_name

  # Lambda 통합 설정 (GenAI 서비스용)
  enable_lambda_integration     = var.enable_lambda_integration
  lambda_function_invoke_arn    = var.lambda_function_invoke_arn
  lambda_integration_timeout_ms = var.lambda_integration_timeout_ms

  # 스로틀링 설정
  throttle_rate_limit  = var.throttle_rate_limit
  throttle_burst_limit = var.throttle_burst_limit

  # 통합 설정
  integration_timeout_ms = var.integration_timeout_ms

  # 로깅 및 추적
  log_retention_days  = var.log_retention_days
  enable_xray_tracing = var.enable_xray_tracing

  # CORS 설정
  enable_cors = var.enable_cors

  # 사용량 계획
  create_usage_plan = var.create_usage_plan

  # 모니터링 설정
  enable_monitoring = var.enable_monitoring
  create_dashboard  = var.create_dashboard
  alarm_actions     = var.alarm_actions

  # 알람 임계값
  error_4xx_threshold           = var.error_4xx_threshold
  error_5xx_threshold           = var.error_5xx_threshold
  latency_threshold             = var.latency_threshold
  integration_latency_threshold = var.integration_latency_threshold

  tags = var.tags
}