# ==========================================
# Monitoring 레이어 출력값
# ==========================================

output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value       = module.cloudwatch.dashboard_url
}

output "dashboard_name" {
  description = "CloudWatch 대시보드 이름"
  value       = module.cloudwatch.dashboard_name
}

output "sns_topic_arn" {
  description = "알람 알림용 SNS 토픽 ARN"
  value       = aws_sns_topic.alerts.arn
}

output "xray_sampling_rule_name" {
  description = "X-Ray 샘플링 규칙 이름"
  value       = aws_xray_sampling_rule.petclinic.rule_name
}

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