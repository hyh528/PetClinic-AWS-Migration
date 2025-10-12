# Secrets Manager 시크릿 ARN 출력
output "secret_arn" {
  description = "생성된 Secrets Manager 시크릿의 ARN입니다."
  value       = aws_secretsmanager_secret.this.arn
}

# Secrets Manager 시크릿 이름 출력
output "secret_name" {
  description = "생성된 Secrets Manager 시크릿의 이름입니다."
  value       = aws_secretsmanager_secret.this.name
}

# Secrets Manager 시크릿 ID 출력
output "secret_id" {
  description = "생성된 Secrets Manager 시크릿의 ID입니다."
  value       = aws_secretsmanager_secret.this.id
}

# Secrets Manager 시크릿 버전 ID 출력
output "secret_version_id" {
  description = "생성된 시크릿 버전의 ID입니다 (초기 버전이 생성된 경우)."
  value       = var.create_initial_version ? aws_secretsmanager_secret_version.this[0].version_id : null
}