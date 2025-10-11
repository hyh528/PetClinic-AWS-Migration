# 보안 그룹 출력
output "ecs_security_group_id" {
  description = "ECS 태스크용 보안 그룹 ID"
  value       = module.security_groups.ecs_security_group_id
}

output "aurora_security_group_id" {
  description = "Aurora 클러스터용 보안 그룹 ID"
  value       = module.security_groups.rds_security_group_id
}

output "alb_security_group_id" {
  description = "ALB용 보안 그룹 ID"
  value       = module.security_groups.alb_security_group_id
}

output "vpce_security_group_id" {
  description = "VPC 엔드포인트용 보안 그룹 ID"
  value       = local.vpce_security_group_id
}

# IAM 출력
output "cli_group_name" {
  description = "CLI 사용자 그룹 이름"
  value       = module.iam_roles.cli_group_name
}

output "user_names" {
  description = "IAM 사용자 이름 목록"
  value       = module.iam_roles.user_names
}

output "rds_secret_access_policy_arn" {
  description = "RDS 시크릿 접근 정책 ARN"
  value       = module.security_groups.rds_secret_access_policy_arn
}

output "parameter_store_access_policy_arn" {
  description = "Parameter Store 접근 정책 ARN"
  value       = module.security_groups.parameter_store_access_policy_arn
}

output "cloudwatch_logs_access_policy_arn" {
  description = "CloudWatch Logs 접근 정책 ARN"
  value       = module.security_groups.cloudwatch_logs_access_policy_arn
}
