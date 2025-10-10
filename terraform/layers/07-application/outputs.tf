# Application 레이어 출력값 - 단순화됨

# ALB 정보
output "alb_dns_name" {
  description = "ALB DNS 이름 (애플리케이션 접근 URL)"
  value       = module.alb.alb_dns_name
}

# ECR 정보
output "ecr_repository_url" {
  description = "ECR 리포지토리 URL (Docker 이미지 푸시용)"
  value       = module.ecr.repository_url
}

# ECS 정보
output "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS 서비스 이름"
  value       = module.ecs.service_name
}