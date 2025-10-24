output "db_url_parameter_path" {
  description = "SSM 파라미터 스토어에 저장된 DB URL의 경로"
  value       = aws_ssm_parameter.common_db_url.name
}

output "db_username_parameter_path" {
  description = "SSM 파라미터 스토어에 저장된 DB 사용자 이름의 경로"
  value       = aws_ssm_parameter.common_db_username.name
}

output "db_master_user_secret_arn" {
  description = "Aurora DB의 마스터 사용자 비밀번호가 저장된 Secrets Manager Secret의 ARN"
  value       = aws_rds_cluster.petclinic_aurora_cluster.master_user_secret[0].secret_arn
  sensitive   = true
}

output "db_kms_key_arn" {
  description = "DB 비밀번호 암호화에 사용된 KMS 키의 ARN"
  value       = aws_kms_key.aurora_secrets.arn
}

output "test_ec2_security_group_id" {
  description = "테스트용 EC2 인스턴스의 보안 그룹 ID"
  value       = aws_security_group.test_ec2_sg.id
}

output "db_cluster_arn" {
  description = "Aurora DB 클러스터의 ARN"
  value       = aws_rds_cluster.petclinic_aurora_cluster.arn
}

output "db_cluster_resource_id" {
  description = "Aurora DB 클러스터의 리소스 ID"
  value       = aws_rds_cluster.petclinic_aurora_cluster.cluster_resource_id
}