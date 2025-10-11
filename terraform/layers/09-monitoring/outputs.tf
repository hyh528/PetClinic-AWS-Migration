# =============================================================================
# Monitoring Layer Outputs - 단순화됨
# =============================================================================

# CloudWatch 대시보드 정보
output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value       = module.cloudwatch.dashboard_url
}

output "dashboard_name" {
  description = "CloudWatch 대시보드 이름"
  value       = module.cloudwatch.dashboard_name
}

# SNS 알림 정보
output "sns_topic_arn" {
  description = "알람 알림용 SNS 토픽 ARN"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "SNS 토픽 이름"
  value       = aws_sns_topic.alerts.name
}

# CloudTrail 정보 (활성화된 경우만)
output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = var.enable_cloudtrail ? module.cloudtrail[0].cloudtrail_arn : null
}

output "cloudtrail_s3_bucket" {
  description = "CloudTrail 로그 S3 버킷 이름"
  value       = var.enable_cloudtrail ? module.cloudtrail[0].s3_bucket_name : null
}

output "cloudtrail_log_group" {
  description = "CloudTrail CloudWatch 로그 그룹 이름"
  value       = var.enable_cloudtrail ? module.cloudtrail[0].cloudwatch_log_group_name : null
}

# 알람 정보
output "active_alarms" {
  description = "활성화된 CloudWatch 알람 목록"
  value = {
    ecs_service_health         = aws_cloudwatch_metric_alarm.ecs_service_health.alarm_name
    aurora_connection_failures = aws_cloudwatch_metric_alarm.aurora_connection_failures.alarm_name
  }
}

# 모니터링 설정 정보
output "monitoring_config" {
  description = "모니터링 설정 정보"
  value = {
    log_retention_days     = var.log_retention_days
    cloudtrail_enabled     = var.enable_cloudtrail
    alert_email_configured = var.alert_email != ""
  }
}