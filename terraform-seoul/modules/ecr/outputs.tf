# ECR 모듈 출력값들

output "repository_url" {
  description = "ECR 리포지토리 URL (Docker 이미지 푸시용)"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_name" {
  description = "ECR 리포지토리 이름"
  value       = aws_ecr_repository.this.name
}

output "repository_arn" {
  description = "ECR 리포지토리 ARN"
  value       = aws_ecr_repository.this.arn
}