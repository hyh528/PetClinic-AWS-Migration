# ==========================================
# WAF CloudWatch Logging Setup (DEPRECATED)
# ==========================================
# Note: These log groups are legacy from WAF Classic (v1) era.
# They use "aws-waf-logs-*" prefix which is outdated.
# WAFv2 should use "aws-wafv2-logs-*" prefix or S3/Kinesis for logging.
#
# Current Status:
# - aws-waf-logs-petclinic-dev-api: Orphaned (not used by any WAF)
# - aws-waf-logs-petclinic-dev-alb: Orphaned (not used by any WAF)
#
# Recommendation: Delete these log groups manually from AWS Console
# or use Terraform import + destroy if they need to be managed.

# COMMENTED OUT - These resources create orphaned log groups
# 
# resource "aws_cloudwatch_log_group" "waf_api_logs" {
#   name              = "aws-waf-logs-${var.name_prefix}-api"
#   retention_in_days = 30
#
#   tags = {
#     Name        = "${var.name_prefix}-waf-api-logs"
#     Environment = var.environment
#     Purpose     = "waf-logging"
#     ManagedBy   = "terraform"
#   }
# }
#
# resource "aws_cloudwatch_log_group" "waf_alb_logs" {
#   name              = "aws-waf-logs-${var.name_prefix}-alb"
#   retention_in_days = 30
#
#   tags = {
#     Name        = "${var.name_prefix}-waf-alb-logs"
#     Environment = var.environment
#     Purpose     = "waf-logging"
#     ManagedBy   = "terraform"
#   }
# }

# COMMENTED OUT - Resource policy for orphaned log groups
#
# data "aws_iam_policy_document" "waf_cloudwatch_logging" {
#   statement {
#     effect = "Allow"
#
#     principals {
#       type        = "Service"
#       identifiers = ["waf.amazonaws.com"]
#     }
#
#     actions = ["logs:PutLogEvents"]
#
#     resources = [
#       aws_cloudwatch_log_group.waf_api_logs.arn,
#       aws_cloudwatch_log_group.waf_alb_logs.arn
#     ]
#
#     condition {
#       test     = "StringEquals"
#       variable = "aws:SourceAccount"
#       values   = [data.aws_caller_identity.current.account_id]
#     }
#
#     condition {
#       test     = "ArnLike"
#       variable = "aws:SourceArn"
#       values   = ["arn:aws:wafv2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:regional/webacl/*"]
#     }
#   }
# }
#
# resource "aws_cloudwatch_log_resource_policy" "waf_logging" {
#   policy_name     = "${var.name_prefix}-waf-logging-policy"
#   policy_document = data.aws_iam_policy_document.waf_cloudwatch_logging.json
# }