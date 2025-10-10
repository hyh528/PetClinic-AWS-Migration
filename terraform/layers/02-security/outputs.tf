# =============================================================================
# Security Layer Outputs - 다른 레이어에서 참조할 보안 리소스 정보
# =============================================================================

# =============================================================================
# 1. 보안 그룹 출력
# =============================================================================

output "ecs_security_group_id" {
  description = "ECS Fargate 태스크용 보안 그룹 ID"
  value       = module.security_groups.ecs_security_group_id
}

output "aurora_security_group_id" {
  description = "Aurora MySQL 클러스터용 보안 그룹 ID"
  value       = module.security_groups.rds_security_group_id
}

output "alb_security_group_id" {
  description = "Application Load Balancer용 보안 그룹 ID"
  value       = module.security_groups.alb_security_group_id
}

output "vpce_security_group_id" {
  description = "VPC 엔드포인트용 보안 그룹 ID (Network 레이어에서 생성됨)"
  value       = local.vpce_security_group_id
}

# =============================================================================
# 2. IAM 사용자 및 그룹 출력
# =============================================================================

output "cli_group_name" {
  description = "CLI 사용자 그룹 이름"
  value       = module.iam_roles.cli_group_name
}

output "cli_group_arn" {
  description = "CLI 사용자 그룹 ARN"
  value       = module.iam_roles.cli_group_arn
}

output "user_names" {
  description = "생성된 IAM 사용자 이름 목록"
  value       = module.iam_roles.user_names
}

output "user_arns" {
  description = "사용자 이름 접미사로 키된 IAM 사용자 ARN 맵"
  value       = module.iam_roles.user_arns
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

# =============================================================================
# 3. 보안 설정 요약
# =============================================================================

output "security_summary" {
  description = "보안 레이어 구성 요약"
  value = {
    security_groups = {
      ecs_sg_id    = module.security_groups.ecs_security_group_id
      aurora_sg_id = module.security_groups.rds_security_group_id
      alb_sg_id    = module.security_groups.alb_security_group_id
      vpce_sg_id   = local.vpce_security_group_id
    }

    iam_users = {
      cli_group_name = module.iam_roles.cli_group_name
      cli_group_arn  = module.iam_roles.cli_group_arn
      user_count     = length(module.iam_roles.user_names)
    }

    policies = {
      rds_secret_access      = module.security_groups.rds_secret_access_policy_arn
      parameter_store_access = module.security_groups.parameter_store_access_policy_arn
      cloudwatch_logs_access = module.security_groups.cloudwatch_logs_access_policy_arn
    }

    # VPC 엔드포인트는 Network 레이어에서 관리됨
    vpc_endpoints_reference = {
      managed_by_layer  = "01-network"
      security_group_id = local.vpce_security_group_id
      note              = "VPC endpoints are managed by the network layer"
    }

    # Cross-Layer 참조 상태
    cross_layer_integration = {
      alb_integration_enabled = var.enable_alb_integration
      alb_sg_referenced       = local.alb_sg_id != ""
      dependencies_ready      = local.dependencies_ready
    }

    # 배포 단계 정보
    deployment_phase = {
      phase_1_basic_security  = true
      phase_2_alb_integration = var.enable_alb_integration
      team_members_count      = length(var.team_members)
      role_based_policies     = var.enable_role_based_policies
    }
  }
}
