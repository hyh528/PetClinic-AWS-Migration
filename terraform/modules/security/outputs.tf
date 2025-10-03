output "ecs_security_group_id" {
  description = "ECS 태스크용 보안 그룹 ID"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "Aurora 클러스터용 보안 그룹 ID (RDS 호환)"
  value       = aws_security_group.rds.id
}