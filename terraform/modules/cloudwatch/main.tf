
locals {
  # 대시보드 위젯을 동적으로 생성합니다.
  # 참고: CloudWatch 대시보드 위젯의 x, y 좌표와 width, height는 24 그리드 시스템을 따릅니다.

  # 서비스별 위젯 생성
  service_widgets = flatten([
    for idx, service_key in keys(var.services) : [
      # --- 서비스 섹션 헤더 ---
      {
        type   = "text"
        x      = 0
        y      = idx * 8 # 각 서비스 섹션의 시작 y 좌표
        width  = 24
        height = 1
        properties = {
          markdown = "## ${upper(service_key)} Service Metrics"
        }
      },
      # --- ECS 위젯 (CPU, Memory 자원 사용률) ---
      {
        type   = "metric"
        x      = 0
        y      = (idx * 8) + 1
        width  = 12
        height = 3
        properties = {
          title   = "${service_key} - ECS CPU & Memory Utilization"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.services[service_key].ecs_cluster_name, "ServiceName", var.services[service_key].ecs_service_name],
            ["...", { "yAxis": "right", "label": "MemoryUtilization" }]
          ]
        }
      },
      # --- ALB 타겟 그룹 위젯 (Healthy/Unhealthy Hosts) 백엔드 서비스 상태 확인용 (정상, 비정상)  ---
      {
        type   = "metric"
        x      = 12
        y      = (idx * 8) + 1
        width  = 12
        height = 3
        properties = {
          title   = "${service_key} - ALB Target Health"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.services[service_key].alb_arn_suffix, "TargetGroup", var.services[service_key].alb_target_group_id],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ]
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      # --- ALB 타겟 그룹 위젯 (5xx, 응답 시간) (ALB에서 백엔드 대상(ecs)과 통신 시 에러 발생 관련)---
      {
        type   = "metric"
        x      = 0
        y      = (idx * 8) + 4
        width  = 12
        height = 3
        properties = {
          title   = "${service_key} - ALB Target Errors & Latency"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.services[service_key].alb_arn_suffix, "TargetGroup", var.services[service_key].alb_target_group_id, { "stat": "Sum" }],
            [".", "TargetResponseTime", ".", ".", ".", ".", { "yAxis": "right", "label": "Avg. Response Time" }]
          ]
        }
      }
    ]
  ])

  # DB 위젯 목록을 미리 정의
  potential_db_widgets = [
    # --- DB 섹션 헤더 ---
    {
      type   = "text",
      x      = 0,
      y      = length(var.services) * 8, # 서비스 섹션 다음에 위치
      width  = 24,
      height = 1,
      properties = {
        markdown = "## Database Metrics (Aurora)"
      }
    },
    # --- DB 위젯 (CPU, Connections) ---
    {
      type   = "metric",
      x      = 0,
      y      = (length(var.services) * 8) + 1,
      width  = 12,
      height = 6,
      properties = {
        title   = "DB - CPU & Connections",
        view    = "timeSeries",
        stacked = false,
        region  = var.aws_region,
        metrics = [
          ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.db_cluster_identifier],
          [".", "DatabaseConnections", ".", ".", { "yAxis": "right" }]
        ]
      }
    },
    # --- DB 위젯 (Memory, Storage) ---
    {
      type   = "metric",
      x      = 12,
      y      = (length(var.services) * 8) + 1,
      width  = 12,
      height = 6,
      properties = {
        title   = "DB - Freeable Memory & Storage",
        view    = "timeSeries",
        stacked = false,
        region  = var.aws_region,
        metrics = [
          ["AWS/RDS", "FreeableMemory", "DBClusterIdentifier", var.db_cluster_identifier],
          ["AWS/Aurora", "FreeLocalStorage", "DBClusterIdentifier", var.db_cluster_identifier, { "yAxis": "right" }]
        ]
      }
    },
    # --- DB 위젯 (Throughput, Latency) ---
    {
      type   = "metric",
      x      = 0,
      y      = (length(var.services) * 8) + 7,
      width  = 12,
      height = 6,
      properties = {
        title   = "DB - Throughput & Latency (Select)",
        view    = "timeSeries",
        stacked = false,
        region  = var.aws_region,
        metrics = [
          ["AWS/RDS", "SelectThroughput", "DBClusterIdentifier", var.db_cluster_identifier],
          [".", "SelectLatency", ".", ".", { "yAxis": "right" }]
        ]
      }
    },
    {
      type   = "metric",
      x      = 12,
      y      = (length(var.services) * 8) + 7,
      width  = 12,
      height = 6,
      properties = {
        title   = "DB - Throughput & Latency (DML)",
        view    = "timeSeries",
        stacked = false,
        region  = var.aws_region,
        metrics = [
          ["AWS/RDS", "DMLThroughput", "DBClusterIdentifier", var.db_cluster_identifier],
          [".", "DMLLatency", ".", ".", { "yAxis": "right" }]
        ]
      }
    }
  ]

  # db_cluster_identifier가 있을 때만 위젯을 생성
  db_widgets = [
    for widget in local.potential_db_widgets : widget if var.db_cluster_identifier != null
  ]

  # 모든 위젯 결합
  all_widgets = concat(local.service_widgets, local.db_widgets)
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-main-dashboard"

  dashboard_body = jsonencode({
    widgets = local.all_widgets
  })
}

# =================================================
# SNS Topic for Alarms
# =================================================
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-${var.environment}-alarms"
}

# =================================================
# CloudWatch Alarms
# =================================================

# ECS Service Alarms
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  for_each = var.services

  alarm_name          = "${each.key}-cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alarm when CPU utilization is greater than or equal to 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = each.value.ecs_cluster_name
    ServiceName = each.value.ecs_service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  for_each = var.services

  alarm_name          = "${each.key}-memory-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alarm when memory utilization is greater than or equal to 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = each.value.ecs_cluster_name
    ServiceName = each.value.ecs_service_name
  }
}

# Database Alarms
resource "aws_cloudwatch_metric_alarm" "db_cpu_utilization" {
  count = var.db_cluster_identifier != null ? 1 : 0

  alarm_name          = "db-cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alarm when DB CPU utilization is greater than or equal to 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBClusterIdentifier = var.db_cluster_identifier
  }
}

# =================================================
# SNS Subscription for Lambda
# =================================================
#
# resource "aws_sns_topic_subscription" "lambda" {
#   topic_arn = aws_sns_topic.alarms.arn
#   protocol  = "lambda"
#   endpoint  = var.lambda_function_arn
# }
#
# resource "aws_lambda_permission" "sns" {
#   statement_id  = "AllowExecutionFromSNS"
#   action        = "lambda:InvokeFunction"
#   function_name = var.lambda_function_name
#   principal     = "sns.amazonaws.com"
#   source_arn    = aws_sns_topic.alarms.arn
# }
