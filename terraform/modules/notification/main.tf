# =============================================================================
# Notification Module - SNS + Lambda Slack 통합
# =============================================================================
# 목적: CloudWatch 알람을 Slack으로 전송하는 알림 시스템 구축

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# =============================================================================
# SNS 토픽 생성
# =============================================================================

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alerts-topic"
    Environment = var.environment
    Type        = "notification"
  })
}

# SNS 토픽 정책 (Lambda 함수가 메시지를 받을 수 있도록)
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# =============================================================================
# Lambda 함수 - Slack 알림
# =============================================================================

# Lambda 함수 코드 압축
data "archive_file" "slack_notifier" {
  type        = "zip"
  output_path = "${path.module}/slack_notifier.zip"

  source {
    content = templatefile("${path.module}/slack_notifier.py", {
      slack_webhook_url = var.slack_webhook_url
      slack_channel     = var.slack_channel
      environment       = var.environment
    })
    filename = "lambda_function.py"
  }
}

# Lambda 실행 역할
resource "aws_iam_role" "slack_notifier" {
  name = "${var.name_prefix}-slack-notifier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-slack-notifier-role"
    Environment = var.environment
  })
}

# Lambda 기본 실행 정책
resource "aws_iam_role_policy_attachment" "slack_notifier_basic" {
  role       = aws_iam_role.slack_notifier.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda 함수
resource "aws_lambda_function" "slack_notifier" {
  filename         = data.archive_file.slack_notifier.output_path
  function_name    = "${var.name_prefix}-slack-notifier"
  role             = aws_iam_role.slack_notifier.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  source_code_hash = data.archive_file.slack_notifier.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      SLACK_CHANNEL     = var.slack_channel
      ENVIRONMENT       = var.environment
      PROJECT_NAME      = var.name_prefix
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-slack-notifier"
    Environment = var.environment
    Type        = "notification"
  })
}

# Lambda 함수 로그 그룹
resource "aws_cloudwatch_log_group" "slack_notifier" {
  name              = "/aws/lambda/${aws_lambda_function.slack_notifier.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-slack-notifier-logs"
    Environment = var.environment
  })
}

# SNS 토픽에서 Lambda 함수 호출 권한
resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# SNS 토픽 구독 (Lambda 함수)
resource "aws_sns_topic_subscription" "slack_notifier" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn

  depends_on = [aws_lambda_permission.sns_invoke]
}

# =============================================================================
# 이메일 알림 (선택사항)
# =============================================================================

resource "aws_sns_topic_subscription" "email" {
  count = var.email_endpoint != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.email_endpoint
}

# =============================================================================
# 알람 테스트 기능
# =============================================================================

# 테스트용 CloudWatch 알람 (선택사항)
resource "aws_cloudwatch_metric_alarm" "notification_test" {
  count = var.create_test_alarm ? 1 : 0

  alarm_name          = "${var.name_prefix}-notification-test"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "TestMetric"
  namespace           = "Custom/Test"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "알림 시스템 테스트용 알람"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-notification-test"
    Environment = var.environment
    Type        = "test"
  })
}