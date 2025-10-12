# =============================================================================
# AWS Native Services Integration Layer
# =============================================================================
# 목적: AWS 네이티브 서비스들 간의 통합과 오케스트레이션
# Well-Architected Framework 준수: 모든 6가지 기둥 적용

# =============================================================================
# Local Values - 공통 설정
# =============================================================================

locals {
  # Well-Architected: Cost Optimization 및 Operational Excellence
  layer_common_tags = merge(var.shared_config.common_tags, {
    Layer     = "10-aws-native"
    Component = "aws-native-integration"
    Purpose   = "petclinic-aws-native-services"
  })
}

# =============================================================================
# AWS Native Services Integration 모듈
# =============================================================================

module "aws_native_integration" {
  source = "../../modules/aws-native-integration"

  # 기본 설정
  name_prefix = var.shared_config.name_prefix
  aws_region  = var.shared_config.aws_region
  common_tags = local.layer_common_tags

  # API Gateway 설정 (data.tf에서 참조)
  api_gateway_rest_api_id      = data.terraform_remote_state.api_gateway.outputs.rest_api_id
  api_gateway_root_resource_id = data.terraform_remote_state.api_gateway.outputs.root_resource_id
  api_gateway_execution_arn    = data.terraform_remote_state.api_gateway.outputs.execution_arn
  api_gateway_api_name         = data.terraform_remote_state.api_gateway.outputs.api_name
  api_gateway_stage_name       = data.terraform_remote_state.api_gateway.outputs.stage_name
  api_gateway_domain_name      = data.terraform_remote_state.api_gateway.outputs.api_domain_name
  api_gateway_stage_arn        = data.terraform_remote_state.api_gateway.outputs.stage_arn

  # Lambda GenAI 설정 (data.tf에서 참조)
  lambda_genai_invoke_arn    = data.terraform_remote_state.lambda_genai.outputs.invoke_arn
  lambda_genai_function_name = data.terraform_remote_state.lambda_genai.outputs.function_name

  # 기능 활성화 플래그
  enable_genai_integration     = var.enable_genai_integration
  enable_monitoring            = var.enable_monitoring
  create_integration_dashboard = var.create_integration_dashboard
  enable_health_checks         = var.enable_health_checks
  enable_waf_protection        = var.enable_waf_protection

  # 보안 설정
  require_api_key = var.require_api_key

  # 성능 및 제한 설정
  genai_integration_timeout_ms = var.genai_integration_timeout_ms
  api_gateway_4xx_threshold    = var.api_gateway_4xx_threshold
  lambda_error_threshold       = var.lambda_error_threshold
  waf_rate_limit               = var.waf_rate_limit

  # 알람 설정
  alarm_actions = var.alarm_actions
}
