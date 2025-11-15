# Parameter Store 모듈 출력값

# 파라미터 정보
output "common_parameters" {
  description = "생성된 공통 파라미터 목록"
  value       = keys(aws_ssm_parameter.common_config)
}

output "environment_parameters" {
  description = "생성된 환경별 파라미터 목록"
  value       = keys(aws_ssm_parameter.environment_config)
}

output "secure_parameters" {
  description = "생성된 보안 파라미터 목록"
  value       = keys(aws_ssm_parameter.secure_config)
  sensitive   = true
}

output "service_parameters" {
  description = "생성된 서비스별 파라미터 목록"
  value       = keys(aws_ssm_parameter.service_config)
}

# 파라미터 통계
output "parameter_summary" {
  description = "Parameter Store 파라미터 요약"
  value = {
    total_parameters  = length(var.common_parameters) + length(var.environment_parameters) + length(var.secure_parameters) + length(var.service_specific_parameters)
    common_count      = length(var.common_parameters)
    environment_count = length(var.environment_parameters)
    secure_count      = length(var.secure_parameters)
    service_count     = length(var.service_specific_parameters)
    parameter_prefix  = var.parameter_prefix
    environment       = var.environment
  }
}

# IAM 정책 정보
output "iam_policy_arn" {
  description = "Parameter Store 읽기 권한 IAM 정책 ARN"
  value       = var.create_iam_policy ? aws_iam_policy.parameter_store_read[0].arn : null
}

output "iam_policy_name" {
  description = "Parameter Store 읽기 권한 IAM 정책 이름"
  value       = var.create_iam_policy ? aws_iam_policy.parameter_store_read[0].name : null
}

# 암호화 정보
output "encryption_info" {
  description = "암호화 설정 정보"
  value = {
    kms_key_id                  = var.kms_key_id
    kms_key_arn                 = var.kms_key_arn
    secure_parameters_encrypted = length(var.secure_parameters) > 0
  }
}

# 접근 정보
output "parameter_access_info" {
  description = "Parameter Store 접근 정보"
  value = {
    parameter_prefix = var.parameter_prefix
    environment      = var.environment
    region           = data.aws_region.current.name

    # Spring Cloud AWS 설정 예시
    spring_cloud_aws_config = {
      "spring.cloud.aws.paramstore.enabled"           = "true"
      "spring.cloud.aws.paramstore.prefix"            = var.parameter_prefix
      "spring.cloud.aws.paramstore.profile-separator" = "/"
      "spring.cloud.aws.paramstore.fail-fast"         = "true"
    }
  }
}

# 로깅 정보
output "logging_info" {
  description = "로깅 설정 정보"
  value = {
    access_logging_enabled = var.enable_access_logging
    log_group_name         = var.enable_access_logging ? aws_cloudwatch_log_group.parameter_store_access[0].name : null
    log_retention_days     = var.log_retention_days
  }
}

# 서비스별 파라미터 경로
output "service_parameter_paths" {
  description = "서비스별 파라미터 경로 정보"
  value = {
    for service in ["customers", "vets", "visits", "admin"] :
    service => "${var.parameter_prefix}/${var.environment}/${service}/"
  }
}

# 마이그레이션 정보
output "migration_info" {
  description = "Spring Cloud Config 마이그레이션 정보"
  value = {
    spring_cloud_config_replaced = true
    parameter_store_ready        = true
    total_parameters             = length(var.common_parameters) + length(var.environment_parameters) + length(var.secure_parameters) + length(var.service_specific_parameters)
    migration_date               = timestamp()
  }
}