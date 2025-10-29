
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
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.services[service_key].alb_target_group_arn_suffix],
            [".", "UnHealthyHostCount", ".", "."]
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
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "TargetGroup", var.services[service_key].alb_target_group_arn_suffix, { "stat": "Sum" }],
            [".", "TargetResponseTime", ".", ".", { "yAxis": "right", "label": "Avg. Response Time" }]
          ]
        }
      }
    ]
  ])

  # 데이터베이스 플레이스홀더 위젯
  db_placeholder_widget = {
    type   = "text"
    x      = 0
    y      = length(var.services) * 8 # 마지막 서비스 섹션 다음에 위치
    width  = 24
    height = 2
    properties = {
      markdown = <<-EOT
## Database Metrics

*(Database resources are not yet defined. This section will be populated once the RDS module is implemented.)*
      EOT
    }
  }

  # 모든 위젯 결합
  all_widgets = concat(local.service_widgets, [local.db_placeholder_widget])
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-main-dashboard"

  dashboard_body = jsonencode({
    widgets = local.all_widgets
  })


}
