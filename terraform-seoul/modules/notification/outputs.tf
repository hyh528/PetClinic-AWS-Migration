# =============================================================================
# Notification Module Outputs
# =============================================================================

output "sns_topic_arn" {
  description = "SNS 토픽 ARN (다른 모듈에서 alarm_actions로 사용)"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "SNS 토픽 이름"
  value       = aws_sns_topic.alerts.name
}

output "lambda_function_arn" {
  description = "Slack 알림 Lambda 함수 ARN"
  value       = aws_lambda_function.slack_notifier.arn
}

output "lambda_function_name" {
  description = "Slack 알림 Lambda 함수 이름"
  value       = aws_lambda_function.slack_notifier.function_name
}

output "notification_system_ready" {
  description = "알림 시스템 준비 상태"
  value       = true
}