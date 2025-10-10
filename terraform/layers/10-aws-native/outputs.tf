# ==========================================
# AWS Native Services 통합 레이어 출력값
# ==========================================
# 클린 아키텍처 원칙: 인터페이스 분리 및 의존성 역전

# ==========================================
# 통합 서비스 정보 (Integration Information)
# ==========================================

output "integration_status" {
  description = "AWS 네이티브 서비스 통합 상태"
  value = {
    genai_integration_enabled = var.enable_genai_integration
    monitoring_enabled        = var.enable_monitoring
    waf_protection_enabled    = var.enable_waf_protection
    health_checks_enabled     = var.enable_health_checks
  }
}

output "service_endpoints" {
  description = "통합된 서비스 엔드포인트 정보"
  value = {
    api_gateway_url = try(data.terraform_remote_state.api_gateway.outputs.api_url, "")
    genai_endpoint  = var.enable_genai_integration ? "${try(data.terraform_remote_state.api_gateway.outputs.api_url, "")}/genai" : ""
  }
  sensitive = false
}

# ==========================================
# 모니터링 정보 (Monitoring Information)
# ==========================================

output "monitoring_resources" {
  description = "생성된 모니터링 리소스 정보"
  value = var.enable_monitoring ? {
    dashboard_name = var.create_integration_dashboard ? aws_cloudwatch_dashboard.aws_native_integration[0].dashboard_name : ""
    dashboard_url  = var.create_integration_dashboard ? "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.aws_native_integration[0].dashboard_name}" : ""

    alarms = {
      api_gateway_4xx = var.enable_monitoring ? aws_cloudwatch_metric_alarm.api_gateway_4xx_errors[0].alarm_name : ""
      lambda_genai    = var.enable_monitoring && var.enable_genai_integration ? aws_cloudwatch_metric_alarm.lambda_genai_errors[0].alarm_name : ""
    }
  } : {}
}

# ==========================================
# 보안 정보 (Security Information)
# ==========================================

output "security_resources" {
  description = "생성된 보안 리소스 정보"
  value = {
    waf_web_acl_arn = var.enable_waf_protection ? aws_wafv2_web_acl.api_gateway_protection[0].arn : ""
    waf_web_acl_id  = var.enable_waf_protection ? aws_wafv2_web_acl.api_gateway_protection[0].id : ""
  }
  sensitive = false
}

# ==========================================
# 헬스체크 정보 (Health Check Information)
# ==========================================

output "health_check_resources" {
  description = "생성된 헬스체크 리소스 정보"
  value = var.enable_health_checks ? {
    route53_health_check_id = aws_route53_health_check.api_gateway_health[0].id
    health_check_fqdn       = aws_route53_health_check.api_gateway_health[0].fqdn
  } : {}
}

# ==========================================
# 비용 추적 정보 (Cost Tracking Information)
# ==========================================

output "cost_tracking_tags" {
  description = "비용 추적을 위한 태그 정보"
  value = {
    project     = var.project_name
    environment = var.environment
    layer       = "aws-native-integration"
    cost_center = var.cost_center
    owner       = var.owner
  }
}

# ==========================================
# 통합 메트릭 (Integration Metrics)
# ==========================================

output "integration_metrics" {
  description = "통합 서비스 메트릭 정보"
  value = {
    total_services_integrated = sum([
      1,                                    # API Gateway (항상 참조)
      1,                                    # Parameter Store (항상 참조)
      1,                                    # Cloud Map (항상 참조)
      var.enable_genai_integration ? 1 : 0, # Lambda GenAI (조건부)
    ])

    monitoring_enabled_services = var.enable_monitoring ? sum([
      1,                                    # API Gateway 모니터링
      var.enable_genai_integration ? 1 : 0, # Lambda GenAI 모니터링
    ]) : 0

    security_features_enabled = sum([
      var.enable_waf_protection ? 1 : 0,
      var.require_api_key ? 1 : 0,
      var.enable_health_checks ? 1 : 0,
    ])
  }
}

# ==========================================
# 참조된 서비스 정보 (Referenced Services Information)
# ==========================================

output "referenced_services" {
  description = "참조된 AWS 네이티브 서비스들의 정보"
  value = {
    api_gateway = {
      rest_api_id = try(data.terraform_remote_state.api_gateway.outputs.rest_api_id, "")
      api_name    = try(data.terraform_remote_state.api_gateway.outputs.api_name, "")
      stage_name  = try(data.terraform_remote_state.api_gateway.outputs.stage_name, "")
    }

    parameter_store = {
      parameters_count = try(length(data.terraform_remote_state.parameter_store.outputs.parameter_names), 0)
    }

    cloud_map = {
      namespace_id   = try(data.terraform_remote_state.cloud_map.outputs.namespace_id, "")
      namespace_name = try(data.terraform_remote_state.cloud_map.outputs.namespace_name, "")
    }

    lambda_genai = var.enable_genai_integration ? {
      function_name = try(data.terraform_remote_state.lambda_genai.outputs.function_name, "")
      function_arn  = try(data.terraform_remote_state.lambda_genai.outputs.function_arn, "")
    } : {}
  }
  sensitive = false
}

# ==========================================
# 설정 요약 (Configuration Summary)
# ==========================================

output "configuration_summary" {
  description = "현재 설정 요약"
  value = {
    # 기본 설정
    project_name = var.project_name
    environment  = var.environment
    aws_region   = var.aws_region

    # 기능 플래그
    features_enabled = {
      genai_integration     = var.enable_genai_integration
      monitoring            = var.enable_monitoring
      health_checks         = var.enable_health_checks
      waf_protection        = var.enable_waf_protection
      integration_dashboard = var.create_integration_dashboard
    }

    # 보안 설정
    security_config = {
      api_key_required        = var.require_api_key
      data_classification     = var.data_classification
      compliance_requirements = var.compliance_requirements
      waf_rate_limit          = var.waf_rate_limit
    }

    # 비용 최적화 설정
    cost_optimization = {
      auto_shutdown_enabled = var.auto_shutdown_enabled
      backup_required       = var.backup_required
      enable_spot_instances = var.enable_spot_instances
    }

    # 운영 설정
    operational_config = {
      log_retention_days   = var.log_retention_days
      xray_tracing_enabled = var.enable_xray_tracing
      xray_tracing_mode    = var.xray_tracing_mode
    }
  }
}

# ==========================================
# Well-Architected Framework 준수 상태
# ==========================================

output "well_architected_compliance" {
  description = "AWS Well-Architected Framework 6가지 기둥 준수 상태"
  value = {
    operational_excellence = {
      automation_enabled = var.enable_monitoring
      monitoring_enabled = var.enable_monitoring
      dashboard_created  = var.create_integration_dashboard
      logging_configured = var.log_retention_days > 0
      tracing_enabled    = var.enable_xray_tracing
    }

    security = {
      waf_protection     = var.enable_waf_protection
      api_key_protection = var.require_api_key
      data_classified    = var.data_classification != "none"
      compliance_defined = var.compliance_requirements != "none"
    }

    reliability = {
      health_checks_enabled     = var.enable_health_checks
      monitoring_enabled        = var.enable_monitoring
      multi_service_integration = true
    }

    performance_efficiency = {
      timeout_optimized     = var.genai_integration_timeout_ms < 30000
      preferred_instances   = length(var.preferred_instance_types) > 0
      vpc_endpoints_enabled = var.enable_vpc_endpoints
    }

    cost_optimization = {
      auto_shutdown_configured = var.auto_shutdown_enabled
      spot_instances_enabled   = var.enable_spot_instances
      cost_tracking_tags       = true
      backup_optimized         = !var.backup_required || var.environment == "dev"
    }

    sustainability = {
      serverless_preferred  = true # Lambda 사용
      managed_services_used = true # API Gateway, Parameter Store 등
      efficient_instances   = contains(var.preferred_instance_types, "t4g.micro")
      auto_scaling_enabled  = var.auto_shutdown_enabled
    }
  }
}