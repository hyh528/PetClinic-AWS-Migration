# Application 레이어 출력 값들 (모듈 기반)

output "alb_dns_name" {
  description = "ALB DNS 이름 (애플리케이션 접근 URL)"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR 리포지토리 URL (Docker 이미지 푸시용)"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "ECR 리포지토리 이름"
  value       = module.ecr.repository_name
}

output "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_id" {
  description = "ECS 클러스터 ID"
  value       = module.ecs.cluster_id
}

output "ecs_service_name" {
  description = "ECS 서비스 이름"
  value       = module.ecs.service_name
}

output "ecs_task_definition_arn" {
  description = "ECS 태스크 정의 ARN"
  value       = module.ecs.task_definition_arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch 로그 그룹 이름"
  value       = module.ecs.cloudwatch_log_group
}

output "ecs_task_execution_role_arn" {
  description = "ECS 태스크 실행 역할 ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}