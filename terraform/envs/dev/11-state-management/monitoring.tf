# ==========================================
# Terraform 상태 관리 모니터링 설정
# ==========================================

# ==========================================
# CloudWatch 대시보드
# ==========================================

resource "aws_cloudwatch_dashboard" "state_management" {
  dashboard_name = "${var.environment}-terraform-state-management"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", module.state_management.s3_bucket_id, "StorageType", "StandardStorage"],
            [".", "NumberOfObjects", ".", ".", ".", "AllStorageTypes"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "S3 버킷 사용량"
          period  = 86400
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", module.state_management.dynamodb_table_name],
            [".", "ConsumedWriteCapacityUnits", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "DynamoDB 사용량"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/aws/cloudtrail' | fields @timestamp, sourceIPAddress, userIdentity.type, eventName, errorCode\n| filter eventSource = \"s3.amazonaws.com\"\n| filter requestParameters.bucketName = \"${module.state_management.s3_bucket_id}\"\n| sort @timestamp desc\n| limit 100"
          region  = var.aws_region
          title   = "S3 버킷 접근 로그"
        }
      }
    ]
  })
}

# ==========================================
# CloudWatch 알람
# ==========================================

# S3 버킷 크기 알람
resource "aws_cloudwatch_metric_alarm" "s3_bucket_size" {
  alarm_name          = "${var.environment}-terraform-state-bucket-size"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = "86400"
  statistic           = "Average"
  threshold           = "1073741824"  # 1GB
  alarm_description   = "Terraform 상태 파일 S3 버킷 크기가 1GB를 초과했습니다"
  alarm_actions       = var.notification_email != "" ? [aws_sns_topic.state_management_alerts[0].arn] : []

  dimensions = {
    BucketName  = module.state_management.s3_bucket_id
    StorageType = "StandardStorage"
  }

  tags = var.tags
}

# DynamoDB 스로틀링 알람
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttling" {
  alarm_name          = "${var.environment}-terraform-lock-throttling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "DynamoDB 테이블에서 스로틀링이 발생했습니다"
  alarm_actions       = var.notification_email != "" ? [aws_sns_topic.state_management_alerts[0].arn] : []

  dimensions = {
    TableName = module.state_management.dynamodb_table_name
  }

  tags = var.tags
}

# KMS 키 사용량 알람
resource "aws_cloudwatch_metric_alarm" "kms_key_usage" {
  alarm_name          = "${var.environment}-terraform-state-kms-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfRequestsSucceeded"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1000"  # 5분간 1000회 초과
  alarm_description   = "KMS 키 사용량이 임계값을 초과했습니다"
  alarm_actions       = var.notification_email != "" ? [aws_sns_topic.state_management_alerts[0].arn] : []

  dimensions = {
    KeyId = module.state_management.kms_key_id
  }

  tags = var.tags
}

# ==========================================
# SNS 알림 설정
# ==========================================

resource "aws_sns_topic" "state_management_alerts" {
  count = var.notification_email != "" ? 1 : 0
  name  = "${var.environment}-terraform-state-alerts"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.state_management_alerts[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ==========================================
# CloudTrail 로그 그룹 (상태 관리 전용)
# ==========================================

resource "aws_cloudwatch_log_group" "state_management_trail" {
  count             = var.enable_cloudtrail_logging ? 1 : 0
  name              = "/aws/cloudtrail/${var.environment}-terraform-state"
  retention_in_days = 30

  tags = var.tags
}

# CloudTrail 설정
resource "aws_cloudtrail" "state_management" {
  count                         = var.enable_cloudtrail_logging ? 1 : 0
  name                          = "${var.environment}-terraform-state-trail"
  s3_bucket_name               = module.state_management.s3_bucket_id
  s3_key_prefix                = "cloudtrail-logs/"
  include_global_service_events = false
  is_multi_region_trail        = false
  enable_logging               = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.state_management_trail[0].arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_logs_role[0].arn

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${module.state_management.s3_bucket_arn}/*"]
    }

    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = [module.state_management.dynamodb_table_arn]
    }
  }

  tags = var.tags
}

# CloudTrail 로그 역할
resource "aws_iam_role" "cloudtrail_logs_role" {
  count = var.enable_cloudtrail_logging ? 1 : 0
  name  = "${var.environment}-terraform-state-cloudtrail-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_logs_policy" {
  count = var.enable_cloudtrail_logging ? 1 : 0
  name  = "${var.environment}-terraform-state-cloudtrail-logs-policy"
  role  = aws_iam_role.cloudtrail_logs_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.state_management_trail[0].arn}:*"
      }
    ]
  })
}

# ==========================================
# 비용 모니터링
# ==========================================

# 비용 예산 설정
resource "aws_budgets_budget" "state_management_cost" {
  name         = "${var.environment}-terraform-state-budget"
  budget_type  = "COST"
  limit_amount = "10"  # $10 USD
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.notification_email != "" ? [var.notification_email] : []
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.notification_email != "" ? [var.notification_email] : []
  }

  tags = var.tags
}