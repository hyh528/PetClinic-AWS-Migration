# =============================================================================
# Notification Layer - 알림 시스템 구축
# =============================================================================
# 목적: SNS + Lambda를 통한 Slack 알림 시스템 구축
# 의존성: 없음 (독립적으로 실행 가능)

# 공통 로컬 변수
locals {
  layer_common_tags = merge(var.tags, {
    Layer     = "12-notification"
    Component = "notification-system"
    Purpose   = "slack-cloudwatch-integration"
  })
}

# =============================================================================
# Data Sources
# =============================================================================

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# Notification 모듈
# =============================================================================

module "notification" {
  source = "../../modules/notification"

  # 기본 설정
  name_prefix = var.name_prefix
  environment = var.environment

  # Slack 설정
  slack_webhook_url = var.slack_webhook_url
  slack_channel     = var.slack_channel

  # 이메일 알림 (선택사항)
  email_endpoint = var.email_endpoint

  # Lambda 설정
  log_retention_days = var.log_retention_days

  # 테스트 설정
  create_test_alarm = var.create_test_alarm

  tags = local.layer_common_tags
}