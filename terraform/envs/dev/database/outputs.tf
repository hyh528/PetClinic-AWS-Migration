output "db_url_parameter_path" {
  description = "SSM 파라미터 스토어에 저장된 DB URL의 경로"
  value       = aws_ssm_parameter.common["database.url"].name
}

output "db_username_parameter_path" {
  description = "SSM 파라미터 스토어에 저장된 DB 사용자 이름의 경로"
  value       = aws_ssm_parameter.common["database.username"].name
}
