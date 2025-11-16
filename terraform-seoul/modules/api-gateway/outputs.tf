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

# 서비스별 리소스 정보 (동적 생성)
output "service_resources" {
  description = "서비스별 리소스 정보"
  value = {
    for service_name, service_config in local.all_services : service_name => {
      resource_id       = aws_api_gateway_resource.services[service_name].id
      proxy_resource_id = aws_api_gateway_resource.service_proxies[service_name].id
      path              = service_config.path
      parent_path       = service_config.parent_path
      description       = service_config.description
      integration_type  = contains(keys(local.lambda_services), service_name) ? "AWS_PROXY" : "HTTP_PROXY"
    }
  }
}

# 전역 프록시 리소스 정보
output "global_proxy_resource" {
  description = "전역 프록시 리소스 정보 (기타 경로용)"
  value = {
    resource_id = aws_api_gateway_resource.global_proxy.id
    path        = aws_api_gateway_resource.global_proxy.path_part
  }
}

# 라우팅 정보
# 라우팅 설정 정보 (동적 생성)
output "routing_configuration" {
  description = "API Gateway 라우팅 설정 정보"
  value = {
    base_url = aws_api_gateway_stage.petclinic.invoke_url
    routes = {
      for service_name, service_config in local.all_services : service_name =>
      service_config.parent_path == "api" ?
      "${aws_api_gateway_stage.petclinic.invoke_url}/api/${service_config.path}" :
      "${aws_api_gateway_stage.petclinic.invoke_url}/${service_config.path}"
    }
    service_details = {
      for service_name, service_config in local.all_services : service_name => {
        path             = service_config.path
        parent_path      = service_config.parent_path
        description      = service_config.description
        integration_type = contains(keys(local.lambda_services), service_name) ? "Lambda" : "ALB"
        full_url         = service_config.parent_path == "api" ? "${aws_api_gateway_stage.petclinic.invoke_url}/api/${service_config.path}" : "${aws_api_gateway_stage.petclinic.invoke_url}/${service_config.path}"
      }
    }
    alb_integration    = var.alb_dns_name
    lambda_integration = var.enable_lambda_integration
  }
}

# CloudWatch 로그 그룹 정보
output "cloudwatch_log_groups" {
  description = "API Gateway CloudWatch 로그 그룹 정보"
  value = {
    access_logs = {
      name = aws_cloudwatch_log_group.api_gateway.name
      arn  = aws_cloudwatch_log_group.api_gateway.arn
    }
    execution_logs = {
      name = aws_cloudwatch_log_group.api_gateway_execution.name
      arn  = aws_cloudwatch_log_group.api_gateway_execution.arn
    }
  }
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
    alb_dns_name                = var.alb_dns_name
    timeout_milliseconds        = var.integration_timeout_ms
    integration_type            = "HTTP_PROXY"
    lambda_integration_enabled  = var.enable_lambda_integration
    lambda_timeout_milliseconds = var.lambda_integration_timeout_ms
    lambda_function_invoke_arn  = var.lambda_function_invoke_arn
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

# CloudWatch 알람 정보 (동적 생성)
output "cloudwatch_alarms" {
  description = "생성된 CloudWatch 알람 정보"
  value = var.enable_monitoring ? {
    for alarm_name, alarm_config in {
      "4xx-error-rate" = {
        metric_name         = "4XXError"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.error_4xx_threshold
        statistic           = "Sum"
        description         = "API Gateway 4XX 에러율이 임계값을 초과했습니다"
      }
      "5xx-error-rate" = {
        metric_name         = "5XXError"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.error_5xx_threshold
        statistic           = "Sum"
        description         = "API Gateway 5XX 에러율이 임계값을 초과했습니다"
      }
      "latency" = {
        metric_name         = "Latency"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.latency_threshold
        statistic           = "Average"
        description         = "API Gateway 평균 지연시간이 임계값을 초과했습니다"
      }
      "integration-latency" = {
        metric_name         = "IntegrationLatency"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.integration_latency_threshold
        statistic           = "Average"
        description         = "API Gateway 통합 지연시간이 임계값을 초과했습니다"
      }
      } : alarm_name => {
      alarm_name  = aws_cloudwatch_metric_alarm.api_alarms[alarm_name].alarm_name
      alarm_arn   = aws_cloudwatch_metric_alarm.api_alarms[alarm_name].arn
      metric_name = alarm_config.metric_name
      threshold   = alarm_config.threshold
      description = alarm_config.description
    }
  } : {}
}

output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value       = var.create_dashboard ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.api_gateway[0].dashboard_name}" : null
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
  value       = local.common_tags
}

# 성능 및 설정 요약
output "configuration_summary" {
  description = "API Gateway 설정 요약"
  value = {
    # 기본 설정
    api_name    = aws_api_gateway_rest_api.petclinic.name
    stage_name  = var.stage_name
    environment = var.environment

    # 서비스 설정
    total_services  = length(local.all_services)
    alb_services    = length(local.alb_services)
    lambda_services = length(local.lambda_services)

    # 기능 설정
    cors_enabled         = var.enable_cors
    xray_tracing_enabled = var.enable_xray_tracing
    monitoring_enabled   = var.enable_monitoring
    dashboard_created    = var.create_dashboard
    usage_plan_created   = var.create_usage_plan

    # 성능 설정
    throttle_rate_limit  = var.throttle_rate_limit
    throttle_burst_limit = var.throttle_burst_limit
    integration_timeout  = var.integration_timeout_ms
    lambda_timeout       = var.lambda_integration_timeout_ms

    # 로깅 설정
    log_retention_days = var.log_retention_days

    # 압축 설정
    minimum_compression_size = var.minimum_compression_size
  }
}

# 헬스체크 및 테스트 정보
output "health_check_urls" {
  description = "서비스별 헬스체크 URL"
  value = {
    for service_name, service_config in local.all_services : service_name =>
    service_config.parent_path == "api" ?
    "${aws_api_gateway_stage.petclinic.invoke_url}/api/${service_config.path}/actuator/health" :
    "${aws_api_gateway_stage.petclinic.invoke_url}/${service_config.path}/actuator/health"
  }
}

# 보안 설정 정보
output "security_configuration" {
  description = "API Gateway 보안 설정 정보"
  value = {
    api_key_source               = var.api_key_source
    disable_execute_api_endpoint = var.disable_execute_api_endpoint
    resource_policy_applied      = var.policy != null
    cors_enabled                 = var.enable_cors
    xray_tracing_enabled         = var.enable_xray_tracing
  }
}