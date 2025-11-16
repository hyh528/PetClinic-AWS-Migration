# ==========================================
# 보안 및 모니터링 설정
# ==========================================

# API Gateway 사용량 계획 (선택사항)
resource "aws_api_gateway_usage_plan" "petclinic" {
  count = var.create_usage_plan ? 1 : 0

  name        = "${var.name_prefix}-usage-plan"
  description = "PetClinic API 사용량 계획 - ${var.environment} 환경"

  api_stages {
    api_id = aws_api_gateway_stage.petclinic.rest_api_id
    stage  = aws_api_gateway_stage.petclinic.stage_name

    # 스테이지별 스로틀링 설정 (선택사항)
    throttle {
      path        = "*/*"
      rate_limit  = var.throttle_rate_limit
      burst_limit = var.throttle_burst_limit
    }
  }

  quota_settings {
    limit  = var.quota_limit
    period = var.quota_period
  }

  throttle_settings {
    rate_limit  = var.throttle_rate_limit
    burst_limit = var.throttle_burst_limit
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-api-usage-plan"
    Type = "usage-plan"
  })
}

# CloudWatch 알람 (동적 생성)
resource "aws_cloudwatch_metric_alarm" "api_alarms" {
  for_each = var.enable_monitoring ? {
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
  } : {}

  alarm_name          = "${var.name_prefix}-api-${each.key}"
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = "2"
  metric_name         = each.value.metric_name
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = each.value.description
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName = aws_api_gateway_rest_api.petclinic.name
    Stage   = aws_api_gateway_stage.petclinic.stage_name
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-api-${each.key}-alarm"
    Type = "monitoring"
  })
}

# CloudWatch 대시보드
resource "aws_cloudwatch_dashboard" "api_gateway" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.name_prefix}-api-gateway-dashboard"

  dashboard_body = jsonencode({
    widgets = concat([
      # 요청 및 에러 메트릭
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.petclinic.name, "Stage", aws_api_gateway_stage.petclinic.stage_name, { "label" = "총 요청 수" }],
            [".", "4XXError", ".", ".", ".", ".", { "label" = "4XX 에러" }],
            [".", "5XXError", ".", ".", ".", ".", { "label" = "5XX 에러" }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "API Gateway 요청 및 에러"
          period  = 300
          region  = data.aws_region.current.name
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # 지연시간 메트릭
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.petclinic.name, "Stage", aws_api_gateway_stage.petclinic.stage_name, { "label" = "전체 지연시간" }],
            [".", "IntegrationLatency", ".", ".", ".", ".", { "label" = "통합 지연시간" }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "API Gateway 지연시간"
          period  = 300
          region  = data.aws_region.current.name
          yAxis = {
            left = {
              min   = 0
              label = "밀리초"
            }
          }
        }
      },
      # 에러율 메트릭 (백분율)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.petclinic.name, "Stage", aws_api_gateway_stage.petclinic.stage_name, { "id" = "e1" }],
            [".", "5XXError", ".", ".", ".", ".", { "id" = "e2" }],
            [".", "Count", ".", ".", ".", ".", { "id" = "total" }],
            [{ "expression" = "(e1 + e2) / total * 100", "label" = "전체 에러율 (%)", "id" = "error_rate" }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "API Gateway 에러율"
          period  = 300
          region  = data.aws_region.current.name
          yAxis = {
            left = {
              min   = 0
              max   = 100
              label = "백분율 (%)"
            }
          }
        }
      },
      # 서비스별 요청 분포 (가능한 경우)
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = concat(
            [["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.petclinic.name, "Stage", aws_api_gateway_stage.petclinic.stage_name, { "label" = "전체 요청" }]],
            # 서비스별 메트릭 (Resource 차원이 있는 경우)
            [for service_name in keys(local.all_services) :
              ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.petclinic.name, "Stage", aws_api_gateway_stage.petclinic.stage_name, "Resource", "/${service_name}", { "label" = "${service_name} 서비스" }]
            ]
          )
          view    = "timeSeries"
          stacked = true
          title   = "서비스별 요청 분포"
          period  = 300
          region  = data.aws_region.current.name
        }
      }
    ], [])
  })
}