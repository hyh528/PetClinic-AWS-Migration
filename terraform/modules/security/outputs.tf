output "ecs_security_group_id" {
  description = "ECS 태스크용 보안 그룹 ID"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "Aurora 클러스터용 보안 그룹 ID (RDS 호환)"
  value       = aws_security_group.rds.id
}

# ALB 보안 그룹 (현재는 없지만 일관성을 위해 빈 값 출력)
output "alb_security_group_id" {
  description = "ALB 보안 그룹 ID (현재 미구현)"
  value       = ""
}

# IAM 정책 출력
output "rds_secret_access_policy_arn" {
  description = "RDS 시크릿 접근 정책 ARN"
  value       = aws_iam_policy.rds_secret_access.arn
}

output "parameter_store_access_policy_arn" {
  description = "Parameter Store 접근 정책 ARN"
  value       = aws_iam_policy.parameter_store_access.arn
}

output "cloudwatch_logs_access_policy_arn" {
  description = "CloudWatch Logs 접근 정책 ARN"
  value       = aws_iam_policy.cloudwatch_logs_access.arn
}