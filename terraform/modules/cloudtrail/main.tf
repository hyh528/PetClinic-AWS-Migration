# ==========================================
# CloudTrail 감사 로그 모듈
# ==========================================
# AWS API 호출 및 보안 이벤트 감사 추적

# CloudTrail용 S3 버킷
resource "aws_s3_bucket" "cloudtrail" {
  bucket = var.cloudtrail_bucket_name

  tags = merge(var.tags, {
    Component = "cloudtrail-storage"
    Purpose   = "audit-logging"
  })
}

# S3 버킷 버전 관리 활성화
resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 버킷 암호화 설정
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cloudtrail.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 버킷 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudTrail용 KMS 키
resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key for CloudTrail encryption"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Component = "cloudtrail-encryption"
  })
}

# KMS 키 별칭
resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/petclinic-cloudtrail"
  target_key_id = aws_kms_key.cloudtrail.key_id
}

# S3 버킷 정책 (CloudTrail 접근 허용)
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.cloudtrail_name}"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.cloudtrail_name}"
          }
        }
      }
    ]
  })
}

# CloudTrail 생성
resource "aws_cloudtrail" "main" {
  name           = var.cloudtrail_name
  s3_bucket_name = aws_s3_bucket.cloudtrail.id
  s3_key_prefix  = "cloudtrail-logs"

  # 모든 리전의 이벤트 기록
  include_global_service_events = true
  is_multi_region_trail         = true

  # 관리 이벤트 및 데이터 이벤트 기록
  enable_logging = true

  # KMS 암호화
  kms_key_id = aws_kms_key.cloudtrail.arn

  # CloudWatch Logs 통합
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_logs.arn

  # 이벤트 선택기 - 관리 이벤트
  event_selector {
    read_write_type                  = "All"
    include_management_events        = true
    exclude_management_event_sources = []

    # 데이터 이벤트 - S3 버킷 접근 로그
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.cloudtrail.arn}/*"]
    }

    # 데이터 이벤트 - Parameter Store 접근 로그
    data_resource {
      type   = "AWS::SSM::Parameter"
      values = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/petclinic/*"]
    }

    # 데이터 이벤트 - Secrets Manager 접근 로그
    data_resource {
      type   = "AWS::SecretsManager::Secret"
      values = ["arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:petclinic/*"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]

  tags = merge(var.tags, {
    Component = "cloudtrail"
    Purpose   = "audit-logging"
  })
}

# CloudWatch 로그 그룹 (CloudTrail용)
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.cloudtrail_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Component = "cloudtrail-logs"
  })
}

# CloudTrail → CloudWatch Logs IAM 역할
resource "aws_iam_role" "cloudtrail_logs" {
  name = "${var.cloudtrail_name}-cloudwatch-logs-role"

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

  tags = var.tags
}

# CloudTrail → CloudWatch Logs IAM 정책
resource "aws_iam_role_policy" "cloudtrail_logs" {
  name = "${var.cloudtrail_name}-cloudwatch-logs-policy"
  role = aws_iam_role.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}

# CloudWatch 메트릭 필터 - 보안 이벤트 감지
resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  name           = "RootAccountUsage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsageCount"
    namespace = "PetClinic/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "UnauthorizedAPICalls"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICallsCount"
    namespace = "PetClinic/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "console_signin_failures" {
  name           = "ConsoleSigninFailures"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = ConsoleLogin) && ($.responseElements.ConsoleLogin = \"Failure\") }"

  metric_transformation {
    name      = "ConsoleSigninFailureCount"
    namespace = "PetClinic/Security"
    value     = "1"
  }
}

# 보안 이벤트 알람
resource "aws_cloudwatch_metric_alarm" "root_usage" {
  alarm_name          = "petclinic-root-account-usage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RootAccountUsageCount"
  namespace           = "PetClinic/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Root 계정 사용이 감지되었습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "petclinic-unauthorized-api-calls"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICallsCount"
  namespace           = "PetClinic/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "무단 API 호출이 감지되었습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "console_signin_failures" {
  alarm_name          = "petclinic-console-signin-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ConsoleSigninFailureCount"
  namespace           = "PetClinic/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "콘솔 로그인 실패가 3회 이상 발생했습니다"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  tags = var.tags
}