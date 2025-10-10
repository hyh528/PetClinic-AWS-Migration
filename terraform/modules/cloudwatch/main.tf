# ==========================================
# CloudWatch 모니터링 모듈
# ==========================================
# AWS 네이티브 서비스들의 통합 모니터링 시스템

# CloudWatch 대시보드 생성
resource "aws_cloudwatch_dashboard" "petclinic_dashboard" {
  dashboard_name = var.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      # API Gateway 메트릭
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name],
            [".", "Latency", ".", "."],
            [".", "4XXError", ".", "."],
            [".", "5XXError", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Metrics"
          period  = 300
        }
      },

      # ECS 서비스 메트릭
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service Metrics"
          period  = 300
        }
      },

      # Lambda 함수 메트릭 (GenAI)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name],
            [".", "Duration", ".", "."],
            [".", "Errors", ".", "."],
            [".", "ConcurrentExecutions", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Function Metrics (GenAI)"
          period  = 300
        }
      },

      # Aurora 데이터베이스 메트릭
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.aurora_cluster_name],
            [".", "DatabaseConnections", ".", "."],
            [".", "ReadLatency", ".", "."],
            [".", "WriteLatency", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Aurora Database Metrics"
          period  = 300
        }
      },

      # ALB 메트릭
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_name],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Application Load Balancer Metrics"
          period  = 300
        }
      },

      # 비즈니스 메트릭 (로그 기반)
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          query  = "SOURCE '/ecs/petclinic-app' | fields @timestamp, @message | filter @message like /actuator/health/ | stats count() by bin(5m)"
          region = var.aws_region
          title  = "Health Check Requests"
          view   = "table"
        }
      }
    ]
  })
}

# CloudWatch 로그 그룹들 (이미 ECS 모듈에서 생성되지만 중앙 관리용)
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.api_gateway_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Component = "api-gateway-logs"
  })
}

resource "aws_cloudwatch_log_group" "lambda_genai" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Component = "lambda-logs"
  })
}

# CloudWatch 메트릭 필터 (비즈니스 메트릭 추출)
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "ErrorCount"
  log_group_name = "/ecs/petclinic-app"
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "PetClinic/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "response_time" {
  name           = "ResponseTime"
  log_group_name = "/ecs/petclinic-app"
  pattern        = "[timestamp, request_id, level, message, response_time]"

  metric_transformation {
    name      = "ResponseTime"
    namespace = "PetClinic/Application"
    value     = "$response_time"
  }
}

# ==========================================
# CloudWatch 알람 설정
# ==========================================

# API Gateway 5XX 에러 알람
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "petclinic-api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "API Gateway 5XX 에러가 임계값을 초과했습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = var.tags
}

# API Gateway 지연시간 알람
resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  alarm_name          = "petclinic-api-gateway-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "API Gateway 평균 지연시간이 1초를 초과했습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = var.tags
}

# ECS CPU 사용률 알람
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "petclinic-ecs-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS 서비스 CPU 사용률이 80%를 초과했습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = var.tags
}

# ECS 메모리 사용률 알람
resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "petclinic-ecs-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS 서비스 메모리 사용률이 80%를 초과했습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = var.tags
}

# Lambda 함수 에러율 알람
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "petclinic-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Lambda 함수 에러가 임계값을 초과했습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = var.tags
}

# Lambda 함수 실행 시간 알람
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "petclinic-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "10000"
  alarm_description   = "Lambda 함수 평균 실행 시간이 10초를 초과했습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = var.tags
}

# Aurora 데이터베이스 연결 수 알람
resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  alarm_name          = "petclinic-aurora-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Aurora 데이터베이스 연결 수가 임계값을 초과했습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_name
  }

  tags = var.tags
}

# Aurora CPU 사용률 알람
resource "aws_cloudwatch_metric_alarm" "aurora_cpu_utilization" {
  alarm_name          = "petclinic-aurora-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Aurora 데이터베이스 CPU 사용률이 80%를 초과했습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_name
  }

  tags = var.tags
}