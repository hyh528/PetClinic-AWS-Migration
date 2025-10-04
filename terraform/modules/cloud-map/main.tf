# Cloud Map 모듈 - Netflix Eureka 대체
# DNS 기반 서비스 디스커버리 제공

# 현재 AWS 리전 정보
data "aws_region" "current" {}

# 프라이빗 DNS 네임스페이스 생성
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = var.namespace_name
  description = var.namespace_description
  vpc         = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-service-discovery"
    Environment = var.environment
    Type        = "service-discovery"
  })
}

# 마이크로서비스별 서비스 생성
resource "aws_service_discovery_service" "microservices" {
  for_each = toset(var.microservices)

  name = each.value

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = var.dns_ttl
      type = var.dns_record_type
    }

    routing_policy = var.routing_policy
  }

  # 헬스체크 설정 (이 속성은 AWS Service Discovery에서 지원되지 않음)
  # health_check_grace_period_seconds = var.health_check_grace_period

  # 헬스체크 커스텀 설정 (선택사항)
  dynamic "health_check_custom_config" {
    for_each = var.enable_custom_health_check ? [1] : []

    content {
      failure_threshold = var.health_check_failure_threshold
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-${each.value}-service"
    Environment = var.environment
    Service     = each.value
    Type        = "service-discovery"
  })
}

# CloudWatch 로그 그룹 (서비스 디스커버리 로그용, 선택사항)
resource "aws_cloudwatch_log_group" "service_discovery" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/servicediscovery/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-service-discovery-logs"
    Environment = var.environment
    Type        = "logging"
  })
}

# CloudWatch 로그 메트릭 필터 (선택사항)
resource "aws_cloudwatch_log_metric_filter" "service_registration" {
  count = var.enable_logging && var.enable_metrics ? 1 : 0

  name           = "${var.name_prefix}-service-registrations"
  log_group_name = aws_cloudwatch_log_group.service_discovery[0].name
  pattern        = "[timestamp, request_id, level=\"INFO\", message=\"Service registered\"]"

  metric_transformation {
    name      = "ServiceRegistrations"
    namespace = "AWS/ServiceDiscovery/Custom"
    value     = "1"

    default_value = 0
  }
}

# 서비스 디스커버리 헬스체크 알람 (선택사항)
resource "aws_cloudwatch_metric_alarm" "service_health" {
  for_each = var.enable_health_alarms ? toset(var.microservices) : []

  alarm_name          = "${var.name_prefix}-${each.value}-service-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyInstanceCount"
  namespace           = "AWS/ServiceDiscovery"
  period              = "300"
  statistic           = "Average"
  threshold           = var.healthy_instance_threshold
  alarm_description   = "${each.value} 서비스의 정상 인스턴스 수가 임계값 미만입니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ServiceName = each.value
    NamespaceId = aws_service_discovery_private_dns_namespace.this.id
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-${each.value}-health-alarm"
    Environment = var.environment
    Service     = each.value
    Type        = "monitoring"
  })
}
