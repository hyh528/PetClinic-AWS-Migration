# API Gateway 모듈 출력값

# API Gateway 기본 정보
output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.petclinic.id
}

output "api_gateway_arn" {
  description = "API Gateway REST API ARN"
  value       = aws_api_gateway_rest_api.petclinic.arn
}

output "api_gateway_name" {
  description = "API Gateway REST API 이름"
  value       = aws_api_gateway_rest_api.petclinic.name
}

output "api_gateway_root_resource_id" {
  description = "API Gateway 루트 리소스 ID"
  value       = aws_api_gateway_rest_api.petclinic.root_resource_id
}

# 배포 및 스테이지 정보
output "api_gateway_deployment_id" {
  description = "API Gateway 배포 ID"
  value       = aws_api_gateway_deployment.petclinic.id
}

output "api_gateway_stage_name" {
  description = "API Gateway 스테이지 이름"
  value       = aws_api_gateway_stage.petclinic.stage_name
}

output "api_gateway_stage_arn" {
  description = "API Gateway 스테이지 ARN"
  value       = aws_api_gateway_stage.petclinic.arn
}

# 엔드포인트 URL
output "api_gateway_invoke_url" {
  description = "API Gateway 호출 URL"
  value       = aws_api_gateway_stage.petclinic.invoke_url
}

output "api_gateway_execution_arn" {
  description = "API Gateway 실행 ARN (Lambda 권한용)"
  value       = aws_api_gateway_rest_api.petclinic.execution_arn
}

# 리소스 정보
output "api_resource_id" {
  description = "API 루트 리소스 ID"
  value       = aws_api_gateway_resource.api.id
}

output "service_resources" {
  description = "서비스별 리소스 정보"
  value = {
    customers = {
      resource_id       = aws_api_gateway_resource.customers.id
      proxy_resource_id = aws_api_gateway_resource.customers_proxy.id
      path              = aws_api_gateway_resource.customers.path_part
    }
    vets = {
      resource_id       = aws_api_gateway_resource.vets.id
      proxy_resource_id = aws_api_gateway_resource.vets_proxy.id
      path              = aws_api_gateway_resource.vets.path_part
    }
    visits = {
      resource_id       = aws_api_gateway_resource.visits.id
      proxy_resource_id = aws_api_gateway_resource.visits_proxy.id
      path              = aws_api_gateway_resource.visits.path_part
    }
    admin = {
      resource_id       = aws_api_gateway_resource.admin.id
      proxy_resource_id = aws_api_gateway_resource.admin_proxy.id
      path              = aws_api_gateway_resource.admin.path_part
    }
    genai = var.enable_lambda_integration ? {
      resource_id       = aws_api_gateway_resource.genai[0].id
      proxy_resource_id = aws_api_gateway_resource.genai_proxy[0].id
      path              = aws_api_gateway_resource.genai[0].path_part
    } : null
  }
}

output "proxy_resource_id" {
  description = "프록시 리소스 ID (기타 경로용)"
  value       = aws_api_gateway_resource.proxy.id
}

output "proxy_resource_path" {
  description = "프록시 리소스 경로"
  value       = aws_api_gateway_resource.proxy.path_part
}

# 라우팅 정보
output "routing_configuration" {
  description = "API Gateway 라우팅 설정 정보"
  value = {
    base_url = aws_api_gateway_stage.petclinic.invoke_url
    routes = {
      customers = "${aws_api_gateway_stage.petclinic.invoke_url}/api/customers"
      vets      = "${aws_api_gateway_stage.petclinic.invoke_url}/api/vets"
      visits    = "${aws_api_gateway_stage.petclinic.invoke_url}/api/visits"
      admin     = "${aws_api_gateway_stage.petclinic.invoke_url}/admin"
      genai     = var.enable_lambda_integration ? "${aws_api_gateway_stage.petclinic.invoke_url}/api/genai" : null
    }
    alb_integration    = var.alb_dns_name
    lambda_integration = var.enable_lambda_integration
  }
}

# CloudWatch 로그 그룹
output "cloudwatch_log_group_name" {
  description = "API Gateway CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "cloudwatch_log_group_arn" {
  description = "API Gateway CloudWatch 로그 그룹 ARN"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

# 사용량 계획 (조건부)
output "usage_plan_id" {
  description = "API Gateway 사용량 계획 ID (생성된 경우)"
  value       = var.create_usage_plan ? aws_api_gateway_usage_plan.petclinic[0].id : null
}

output "usage_plan_arn" {
  description = "API Gateway 사용량 계획 ARN (생성된 경우)"
  value       = var.create_usage_plan ? aws_api_gateway_usage_plan.petclinic[0].arn : null
}

# 설정 정보
output "throttle_settings" {
  description = "API Gateway 스로틀링 설정"
  value = {
    rate_limit  = var.throttle_rate_limit
    burst_limit = var.throttle_burst_limit
  }
}

output "integration_settings" {
  description = "ALB 통합 설정 정보"
  value = {
    alb_dns_name                    = var.alb_dns_name
    timeout_milliseconds           = var.integration_timeout_ms
    integration_type               = "HTTP_PROXY"
    lambda_integration_enabled     = var.enable_lambda_integration
    lambda_timeout_milliseconds    = var.lambda_integration_timeout_ms
    lambda_function_invoke_arn     = var.lambda_function_invoke_arn
  }
}

# 보안 및 기능 설정
output "cors_enabled" {
  description = "CORS 활성화 여부"
  value       = var.enable_cors
}

output "xray_tracing_enabled" {
  description = "X-Ray 추적 활성화 여부"
  value       = var.enable_xray_tracing
}

# 모니터링 정보
output "monitoring_enabled" {
  description = "모니터링 활성화 여부"
  value       = var.enable_monitoring
}

output "cloudwatch_alarms" {
  description = "생성된 CloudWatch 알람 정보"
  value = var.enable_monitoring ? {
    error_4xx_alarm_name = aws_cloudwatch_metric_alarm.api_4xx_error_rate[0].alarm_name
    error_5xx_alarm_name = aws_cloudwatch_metric_alarm.api_5xx_error_rate[0].alarm_name
    latency_alarm_name   = aws_cloudwatch_metric_alarm.api_latency[0].alarm_name
    integration_latency_alarm_name = aws_cloudwatch_metric_alarm.api_integration_latency[0].alarm_name
  } : {}
}

output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value = var.create_dashboard ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.api_gateway[0].dashboard_name}" : null
}

output "monitoring_metrics" {
  description = "모니터링 메트릭 정보"
  value = {
    namespace = "AWS/ApiGateway"
    dimensions = {
      ApiName = aws_api_gateway_rest_api.petclinic.name
      Stage   = aws_api_gateway_stage.petclinic.stage_name
    }
    key_metrics = [
      "Count",
      "4XXError", 
      "5XXError",
      "Latency",
      "IntegrationLatency",
      "CacheHitCount",
      "CacheMissCount"
    ]
  }
}

# 태그 정보
output "tags" {
  description = "API Gateway에 적용된 태그"
  value       = merge(var.tags, {
    Name        = "${var.name_prefix}-api-gateway"
    Environment = var.environment
    Service     = "api-gateway"
    ManagedBy   = "terraform"
  })
}