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

# CloudTrail 정보
output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = module.cloudtrail.cloudtrail_arn
}

output "cloudtrail_s3_bucket" {
  description = "CloudTrail 로그 S3 버킷 이름"
  value       = module.cloudtrail.s3_bucket_name
}

output "cloudtrail_log_group" {
  description = "CloudTrail CloudWatch 로그 그룹 이름"
  value       = module.cloudtrail.cloudwatch_log_group_name
}

# 모니터링 설정 정보
output "monitoring_config" {
  description = "모니터링 설정 정보"
  value = {
    alert_email_configured = var.alert_email != ""
  }
}
