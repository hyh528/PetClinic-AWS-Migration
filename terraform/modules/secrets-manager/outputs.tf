# Secrets Manager 시크릿 ARN 출력
output "secret_arn" {
  description = "The ARN of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.arn
}

# Secrets Manager 시크릿 이름 출력
output "secret_name" {
  description = "The name of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.name
}