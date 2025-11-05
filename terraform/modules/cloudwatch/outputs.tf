
output "dashboard_name" {
  description = "생성된 CloudWatch 대시보드의 이름"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "생성된 CloudWatch 대시보드의 ARN"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "sns_topic_arn" {
  description = "알람을 위한 SNS 토픽의 ARN"
  value       = aws_sns_topic.alarms.arn
}
