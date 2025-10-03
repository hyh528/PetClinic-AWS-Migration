# Cloud Map 모듈 출력값

# 네임스페이스 정보
output "namespace_id" {
  description = "프라이빗 DNS 네임스페이스 ID"
  value       = aws_service_discovery_private_dns_namespace.this.id
}

output "namespace_arn" {
  description = "프라이빗 DNS 네임스페이스 ARN"
  value       = aws_service_discovery_private_dns_namespace.this.arn
}

output "namespace_name" {
  description = "프라이빗 DNS 네임스페이스 이름"
  value       = aws_service_discovery_private_dns_namespace.this.name
}

output "namespace_hosted_zone" {
  description = "네임스페이스 호스팅 영역 ID"
  value       = aws_service_discovery_private_dns_namespace.this.hosted_zone
}

# 서비스 정보
output "services" {
  description = "생성된 서비스 디스커버리 서비스 정보"
  value = {
    for service_name, service in aws_service_discovery_service.microservices :
    service_name => {
      id   = service.id
      arn  = service.arn
      name = service.name
    }
  }
}

output "service_ids" {
  description = "서비스 디스커버리 서비스 ID 목록"
  value = {
    for service_name, service in aws_service_discovery_service.microservices :
    service_name => service.id
  }
}

output "service_arns" {
  description = "서비스 디스커버리 서비스 ARN 목록"
  value = {
    for service_name, service in aws_service_discovery_service.microservices :
    service_name => service.arn
  }
}

# DNS 이름 정보
output "service_dns_names" {
  description = "각 마이크로서비스의 DNS 이름"
  value = {
    for service_name in var.microservices :
    service_name => "${service_name}.${var.namespace_name}"
  }
}

output "service_discovery_endpoints" {
  description = "서비스 디스커버리 엔드포인트 정보"
  value = {
    for service_name in var.microservices :
    service_name => {
      dns_name    = "${service_name}.${var.namespace_name}"
      port        = 8080  # 기본 애플리케이션 포트
      protocol    = "http"
      health_path = "/actuator/health"
    }
  }
}

# 설정 정보
output "dns_configuration" {
  description = "DNS 설정 정보"
  value = {
    ttl           = var.dns_ttl
    record_type   = var.dns_record_type
    routing_policy = var.routing_policy
  }
}

output "health_check_configuration" {
  description = "헬스체크 설정 정보"
  value = {
    grace_period_seconds = var.health_check_grace_period
    custom_enabled      = var.enable_custom_health_check
    failure_threshold   = var.health_check_failure_threshold
  }
}

# 모니터링 정보
output "monitoring_info" {
  description = "모니터링 설정 정보"
  value = {
    logging_enabled      = var.enable_logging
    metrics_enabled      = var.enable_metrics
    health_alarms_enabled = var.enable_health_alarms
    log_group_name       = var.enable_logging ? aws_cloudwatch_log_group.service_discovery[0].name : null
  }
}

# CloudWatch 알람 정보
output "health_alarms" {
  description = "생성된 헬스체크 알람 정보"
  value = var.enable_health_alarms ? {
    for service_name in var.microservices :
    service_name => {
      alarm_name = aws_cloudwatch_metric_alarm.service_health[service_name].alarm_name
      alarm_arn  = aws_cloudwatch_metric_alarm.service_health[service_name].arn
    }
  } : {}
}

# ECS 통합 정보
output "ecs_integration_info" {
  description = "ECS 서비스 통합을 위한 정보"
  value = {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    services = {
      for service_name, service in aws_service_discovery_service.microservices :
      service_name => {
        service_id = service.id
        dns_name   = "${service_name}.${var.namespace_name}"
        # ECS 서비스 정의에서 사용할 service_registries 블록 정보
        service_registry = {
          registry_arn = service.arn
        }
      }
    }
  }
}

# 마이그레이션 정보
output "migration_info" {
  description = "Netflix Eureka 마이그레이션 정보"
  value = {
    eureka_discovery_replaced = true
    cloud_map_ready          = true
    namespace_name           = var.namespace_name
    registered_services      = var.microservices
    migration_date           = timestamp()
  }
}