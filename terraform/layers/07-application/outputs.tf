# =============================================================================
# Application Layer Outputs - 단일 책임 원칙 적용된 출력값
# =============================================================================

# =============================================================================
# ALB 관련 출력값
# =============================================================================

output "alb_dns_name" {
  description = "ALB DNS 이름 (애플리케이션 접근 URL)"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "ALB 호스팅 영역 ID (Route53 연동용)"
  value       = module.alb.alb_zone_id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "ALB 타겟 그룹 ARN"
  value       = module.alb.default_target_group_arn
}

# =============================================================================
# ECR 관련 출력값 (멀티 서비스 지원)
# =============================================================================

output "ecr_repositories" {
  description = "각 서비스별 ECR 리포지토리 정보"
  value = {
    for service_key, service_config in local.services : service_key => {
      repository_url  = module.ecr_services[service_key].repository_url
      repository_arn  = module.ecr_services[service_key].repository_arn
      repository_name = module.ecr_services[service_key].repository_name
    }
  }
}

# =============================================================================
# ECS 관련 출력값 (멀티 서비스 지원)
# =============================================================================

output "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS 클러스터 ARN"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_services" {
  description = "각 서비스별 ECS 서비스 정보"
  value = {
    for service_key, service_config in local.services : service_key => {
      service_name           = aws_ecs_service.services[service_key].name
      service_id             = aws_ecs_service.services[service_key].id
      task_definition_arn    = aws_ecs_task_definition.services[service_key].arn
      desired_count          = aws_ecs_service.services[service_key].desired_count
    }
  }
}

# =============================================================================
# 통합 정보 출력값
# =============================================================================

output "application_url" {
  description = "애플리케이션 접근 URL"
  value       = "http://${module.alb.alb_dns_name}"
}

output "health_check_url" {
  description = "헬스체크 URL"
  value       = "http://${module.alb.alb_dns_name}/actuator/health"
}

output "deployment_info" {
  description = "배포 관련 정보 (멀티 서비스)"
  value = {
    ecr_repositories = {
      for service_key, service_config in local.services : service_key => module.ecr_services[service_key].repository_url
    }
    cluster_name = aws_ecs_cluster.main.name
    services = {
      for service_key, service_config in local.services : service_key => aws_ecs_service.services[service_key].name
    }
    alb_dns_name = module.alb.alb_dns_name
  }
}