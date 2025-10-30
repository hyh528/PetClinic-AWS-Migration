
output "dashboard_name" {
  description = "생성된 CloudWatch 대시보드의 이름"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "생성된 CloudWatch 대시보드의 ARN"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}
