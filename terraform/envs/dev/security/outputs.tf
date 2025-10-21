# Security 레이어의 출력 값들을 정의합니다.

# ALB 보안 그룹 ID
output "alb_security_group_id" {
  description = "ALB 보안 그룹의 ID"
  value       = module.sg_alb.security_group_id
}

# App 보안 그룹 ID
output "app_security_group_id" {
  description = "App (ECS) 보안 그룹의 ID"
  value       = module.sg_app.security_group_id
}

# DB 보안 그룹 ID
output "db_security_group_id" {
  description = "DB (Aurora) 보안 그룹의 ID"
  value       = module.sg_db.security_group_id
}

# 모든 보안 그룹 ID를 맵으로 출력
output "security_group_ids" {
  description = "모든 보안 그룹 ID의 맵"
  value = {
    alb = module.sg_alb.security_group_id
    app = module.sg_app.security_group_id
    db  = module.sg_db.security_group_id
  }
}

# VPC Endpoint 보안 그룹 ID
output "vpc_endpoint_security_group_id" {
  description = "VPC Endpoint 보안 그룹 ID"
  value       = module.sg_vpce.security_group_id
}

# Cognito 정보 (나중에 사용)
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID (나중에 사용)"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID (나중에 사용)"
  value       = module.cognito.user_pool_client_id
}

output "api_gateway_cloudwatch_logs_role_arn" {
  description = "API Gateway CloudWatch 로깅 역할 ARN"
  value       = module.iam.api_gateway_cloudwatch_logs_role_arn
}

output "ecs_task_role_arn" {
  description = "ECS Task Role ARN"
  value       = module.iam.ecs_task_role_arn
}

output "ecs_secrets_policy_arn" {
  description = "ARN of the policy for ECS to access secrets"
  value       = module.iam.ecs_secrets_policy_arn
}