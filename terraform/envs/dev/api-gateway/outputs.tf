# API Gateway 레이어 출력값 - 단일 책임 원칙 적용

# API Gateway 기본 정보
output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_gateway_id
}

output "api_gateway_invoke_url" {
  description = "API Gateway 호출 URL"
  value       = module.api_gateway.api_gateway_invoke_url
}

output "api_gateway_stage_name" {
  description = "API Gateway 스테이지 이름"
  value       = module.api_gateway.api_gateway_stage_name
}

output "api_gateway_execution_arn" {
  description = "API Gateway 실행 ARN"
  value       = module.api_gateway.api_gateway_execution_arn
}

# 라우팅 정보
output "routing_configuration" {
  description = "API Gateway 라우팅 설정 정보"
  value       = module.api_gateway.routing_configuration
}

output "service_resources" {
  description = "서비스별 리소스 정보"
  value       = module.api_gateway.service_resources
}

# 모니터링 정보
output "monitoring_info" {
  description = "모니터링 설정 정보"
  value = {
    monitoring_enabled = module.api_gateway.monitoring_enabled
    cloudwatch_alarms  = module.api_gateway.cloudwatch_alarms
    dashboard_url      = module.api_gateway.dashboard_url
    metrics_namespace  = module.api_gateway.monitoring_metrics.namespace
  }
}

# 통합 정보
output "integration_info" {
  description = "ALB 통합 정보"
  value = {
    alb_dns_name         = data.terraform_remote_state.application.outputs.alb_dns_name
    integration_timeout  = var.integration_timeout_ms
    throttle_rate_limit  = var.throttle_rate_limit
    throttle_burst_limit = var.throttle_burst_limit
  }
}

# 마이그레이션 상태
output "migration_status" {
  description = "Spring Cloud Gateway 마이그레이션 상태"
  value = {
    spring_cloud_gateway_replaced = true
    api_gateway_url              = module.api_gateway.api_gateway_invoke_url
    migration_date               = timestamp()
    monitoring_enabled           = var.enable_monitoring
  }
}