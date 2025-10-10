# Parameter Store 레이어 출력값 - 단일 책임 원칙 적용

# 파라미터 정보
output "parameter_summary" {
  description = "Parameter Store 파라미터 요약"
  value       = module.parameter_store.parameter_summary
}

output "common_parameters" {
  description = "생성된 공통 파라미터 목록"
  value       = module.parameter_store.common_parameters
}

output "environment_parameters" {
  description = "생성된 환경별 파라미터 목록"
  value       = module.parameter_store.environment_parameters
}

output "secure_parameters" {
  description = "생성된 보안 파라미터 목록"
  value       = module.parameter_store.secure_parameters
  sensitive   = true
}

output "service_parameters" {
  description = "생성된 서비스별 파라미터 목록"
  value       = module.parameter_store.service_parameters
}

# IAM 정보
output "iam_policy_arn" {
  description = "Parameter Store 읽기 권한 IAM 정책 ARN"
  value       = module.parameter_store.iam_policy_arn
}

output "iam_policy_name" {
  description = "Parameter Store 읽기 권한 IAM 정책 이름"
  value       = module.parameter_store.iam_policy_name
}

# 암호화 정보
output "encryption_info" {
  description = "암호화 설정 정보"
  value       = module.parameter_store.encryption_info
}

# Spring Cloud AWS 설정 정보
output "spring_cloud_aws_config" {
  description = "Spring Cloud AWS Parameter Store 설정"
  value       = module.parameter_store.parameter_access_info.spring_cloud_aws_config
}

# 서비스별 파라미터 경로
output "service_parameter_paths" {
  description = "서비스별 파라미터 경로 정보"
  value       = module.parameter_store.service_parameter_paths
}

# 데이터베이스 연결 정보
output "database_connection_info" {
  description = "데이터베이스 연결 설정 정보"
  value = {
    aurora_endpoint = data.terraform_remote_state.application.outputs.aurora_cluster_endpoint
    database_names = [
      "petclinic_customers",
      "petclinic_vets", 
      "petclinic_visits"
    ]
    username = var.database_username
    ssl_enabled = true
  }
  sensitive = true
}

# 마이그레이션 상태
output "migration_status" {
  description = "Spring Cloud Config 마이그레이션 상태"
  value = {
    spring_cloud_config_replaced = true
    parameter_store_ready        = true
    total_parameters            = module.parameter_store.parameter_summary.total_parameters
    migration_date              = timestamp()
    parameter_prefix            = var.parameter_prefix
    environment                 = var.environment
  }
}