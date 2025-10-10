# Security 레이어 출력 값들

output "aurora_security_group_id" {
  description = "Aurora 클러스터용 보안 그룹 ID"
  value       = module.security.rds_security_group_id
}

output "ecs_security_group_id" {
  description = "ECS용 보안 그룹 ID"
  value       = module.security.ecs_security_group_id
}


output "vpce_security_group_id" {
  description = "VPC 엔드포인트용 보안 그룹 ID"
  value       = module.endpoints.vpce_security_group_id
}

output "rds_secret_access_policy_arn" {
  description = "RDS 관리 시크릿 접근 정책 ARN"
  value       = aws_iam_policy.rds_secret_access.arn
}
