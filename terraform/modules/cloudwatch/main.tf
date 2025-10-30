
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
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.services[service_key].alb_load_balancer_arn_suffix, "TargetGroup", "targetgroup/tg-${service_key}/${var.services[service_key].alb_target_group_id}"],
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
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.services[service_key].alb_load_balancer_arn_suffix, "TargetGroup", "targetgroup/tg-${service_key}/${var.services[service_key].alb_target_group_id}", { "stat": "Sum" }],
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
