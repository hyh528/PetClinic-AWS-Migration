output "db_url_parameter_path" {
  description = "SSM 파라미터 스토어에 저장된 DB URL의 경로"
  value       = aws_ssm_parameter.common["database.url"].name
}

output "db_username_parameter_path" {
  description = "SSM 파라미터 스토어에 저장된 DB 사용자 이름의 경로"
  value       = aws_ssm_parameter.common["database.username"].name
}

output "db_master_user_secret_arn" {
  description = "Aurora DB의 마스터 사용자 비밀번호가 저장된 Secrets Manager Secret의 ARN"
  value       = aws_rds_cluster.petclinic_aurora_cluster.master_user_secret[0].secret_arn
  sensitive   = true
}
