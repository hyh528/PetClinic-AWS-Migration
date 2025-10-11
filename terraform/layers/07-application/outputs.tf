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
# ECR 관련 출력값
# =============================================================================

output "ecr_repository_url" {
  description = "ECR 리포지토리 URL (Docker 이미지 푸시용)"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ECR 리포지토리 ARN"
  value       = module.ecr.repository_arn
}

output "ecr_repository_name" {
  description = "ECR 리포지토리 이름"
  value       = module.ecr.repository_name
}

# =============================================================================
# ECS 관련 출력값
# =============================================================================

output "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS 클러스터 ARN"
  value       = module.ecs.cluster_arn
}

output "ecs_service_name" {
  description = "ECS 서비스 이름"
  value       = module.ecs.service_name
}

output "ecs_service_id" {
  description = "ECS 서비스 ID"
  value       = module.ecs.service_id
}

output "ecs_task_definition_arn" {
  description = "ECS 태스크 정의 ARN"
  value       = module.ecs.task_definition_arn
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
  description = "배포 관련 정보"
  value = {
    ecr_repository = module.ecr.repository_url
    cluster_name   = module.ecs.cluster_name
    service_name   = module.ecs.service_name
    alb_dns_name   = module.alb.alb_dns_name
  }
}