# =============================================================================
# ECS 모니터링 및 알람 설정
# =============================================================================

# ECS 서비스별 CPU 사용률 알람
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = var.enable_ecs_monitoring ? local.services : {}

  alarm_name          = "${var.name_prefix}-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "ECS 서비스 ${each.key}의 CPU 사용률이 80%를 초과했습니다"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.services[each.key].name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
    Type    = "monitoring"
  })
}

# ECS 서비스별 메모리 사용률 알람
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  for_each = var.enable_ecs_monitoring ? local.services : {}

  alarm_name          = "${var.name_prefix}-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "ECS 서비스 ${each.key}의 메모리 사용률이 85%를 초과했습니다"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.services[each.key].name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
    Type    = "monitoring"
  })
}

# ECS 서비스별 실행 중인 태스크 수 알람
resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks_low" {
  for_each = var.enable_ecs_monitoring ? local.services : {}

  alarm_name          = "${var.name_prefix}-${each.key}-running-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "ECS 서비스 ${each.key}의 실행 중인 태스크 수가 1개 미만입니다"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = aws_ecs_service.services[each.key].name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
    Type    = "monitoring"
  })
}

# ALB 타겟 그룹별 건강하지 않은 호스트 알람
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  for_each = var.enable_ecs_monitoring ? local.services : {}

  alarm_name          = "${var.name_prefix}-${each.key}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "ALB 타겟 그룹 ${each.key}에 건강하지 않은 호스트가 있습니다"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.services[each.key].arn_suffix
    LoadBalancer = module.alb.alb_arn_suffix
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
    Type    = "monitoring"
  })
}

# ALB 타겟 그룹별 응답 시간 알람
resource "aws_cloudwatch_metric_alarm" "alb_response_time_high" {
  for_each = var.enable_ecs_monitoring ? local.services : {}

  alarm_name          = "${var.name_prefix}-${each.key}-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.response_time_threshold
  alarm_description   = "ALB 타겟 그룹 ${each.key}의 평균 응답 시간이 5초를 초과했습니다"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.services[each.key].arn_suffix
    LoadBalancer = module.alb.alb_arn_suffix
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
    Type    = "monitoring"
  })
}

# ALB 타겟 그룹별 5XX 에러 알람
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  for_each = local.services

  alarm_name          = "${var.name_prefix}-${each.key}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_5xx_threshold
  alarm_description   = "ALB 타겟 그룹 ${each.key}에서 5분간 5XX 에러가 10개를 초과했습니다"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.services[each.key].arn_suffix
    LoadBalancer = module.alb.alb_arn_suffix
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
    Type    = "monitoring"
  })
}

# =============================================================================
# CloudWatch 대시보드
# =============================================================================

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${var.name_prefix}-application-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # ECS CPU 사용률
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = tolist([
            for service in keys(local.services) : [
              "AWS/ECS", "CPUUtilization", "ServiceName",
              aws_ecs_service.services[service].name, "ClusterName",
              aws_ecs_cluster.main.name
            ]
          ])
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS CPU Utilization (%)"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # ECS 메모리 사용률
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = tolist([
            for service in keys(local.services) : [
              "AWS/ECS", "MemoryUtilization", "ServiceName",
              aws_ecs_service.services[service].name, "ClusterName",
              aws_ecs_cluster.main.name
            ]
          ])
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Memory Utilization (%)"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # ALB 요청 수
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = tolist([
            for service in keys(local.services) : [
              "AWS/ApplicationELB", "RequestCount", "TargetGroup",
              aws_lb_target_group.services[service].arn_suffix, "LoadBalancer",
              module.alb.alb_arn_suffix
            ]
          ])
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Request Count"
        }
      },
      # ALB 응답 시간
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = tolist([
            for service in keys(local.services) : [
              "AWS/ApplicationELB", "TargetResponseTime", "TargetGroup",
              aws_lb_target_group.services[service].arn_suffix, "LoadBalancer",
              module.alb.alb_arn_suffix
            ]
          ])
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Response Time (seconds)"
        }
      },
      # ECS 실행 중인 태스크 수
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = tolist([
            for service in keys(local.services) : [
              "AWS/ECS", "RunningTaskCount", "ServiceName",
              aws_ecs_service.services[service].name, "ClusterName",
              aws_ecs_cluster.main.name
            ]
          ])
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Running Task Count"
        }
      },
      # ALB HTTP 상태 코드
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = tolist(flatten([
            for service in keys(local.services) : [
              ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "TargetGroup", aws_lb_target_group.services[service].arn_suffix, "LoadBalancer", module.alb.alb_arn_suffix],
              ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "TargetGroup", aws_lb_target_group.services[service].arn_suffix, "LoadBalancer", module.alb.alb_arn_suffix],
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "TargetGroup", aws_lb_target_group.services[service].arn_suffix, "LoadBalancer", module.alb.alb_arn_suffix]
            ]
          ]))
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB HTTP Status Codes"
        }
      }
    ]
  })


}