# =============================================================================
# Notification Layer Outputs
# =============================================================================

output "sns_topic_arn" {
  description = "SNS 토픽 ARN (다른 레이어에서 alarm_actions로 사용)"
  value       = module.notification.sns_topic_arn
}

output "sns_topic_name" {
  description = "SNS 토픽 이름"
  value       = module.notification.sns_topic_name
}

output "lambda_function_arn" {
  description = "Slack 알림 Lambda 함수 ARN"
  value       = module.notification.lambda_function_arn
}

output "lambda_function_name" {
  description = "Slack 알림 Lambda 함수 이름"
  value       = module.notification.lambda_function_name
}

output "notification_system_ready" {
  description = "알림 시스템 준비 상태"
  value       = module.notification.notification_system_ready
}