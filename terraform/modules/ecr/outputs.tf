output "repository_urls" {
  description = "ECR 리포지토리의 URL 정보"
  value = { for i in aws_ecr_repository.this : i.name => i.repository_url}
}