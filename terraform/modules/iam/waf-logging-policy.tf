# ==========================================
# WAF CloudWatch Logging Setup
# ==========================================

# WAF 로깅용 CloudWatch 로그 그룹들
resource "aws_cloudwatch_log_group" "waf_api_logs" {
  name              = "aws-waf-logs-${var.name_prefix}-api"
  retention_in_days = 30

  tags = {
    Name        = "${var.name_prefix}-waf-api-logs"
    Environment = var.environment
    Purpose     = "waf-logging"
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "waf_alb_logs" {
  name              = "aws-waf-logs-${var.name_prefix}-alb"
  retention_in_days = 30

  tags = {
    Name        = "${var.name_prefix}-waf-alb-logs"
    Environment = var.environment
    Purpose     = "waf-logging"
    ManagedBy   = "terraform"
  }
}

# WAF 로깅을 위한 리소스 기반 정책
data "aws_iam_policy_document" "waf_cloudwatch_logging" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["waf.amazonaws.com"]
    }

    actions = ["logs:PutLogEvents"]

    resources = [
      aws_cloudwatch_log_group.waf_api_logs.arn,
      aws_cloudwatch_log_group.waf_alb_logs.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:wafv2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:regional/webacl/*"]
    }
  }
}

# CloudWatch Logs 리소스 정책 연결
resource "aws_cloudwatch_log_resource_policy" "waf_logging" {
  policy_name     = "${var.name_prefix}-waf-logging-policy"
  policy_document = data.aws_iam_policy_document.waf_cloudwatch_logging.json
}