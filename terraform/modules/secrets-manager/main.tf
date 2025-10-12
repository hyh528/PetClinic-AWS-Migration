# Secrets Manager 시크릿 생성
resource "aws_secretsmanager_secret" "this" {
  name                    = var.secret_name
  description             = var.secret_description
  recovery_window_in_days = var.recovery_window_in_days

  # KMS 키를 사용한 암호화 (설계서 8.4절 요구사항)
  kms_key_id = var.kms_key_id



  tags = {
    Name        = var.secret_name
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "민감 정보 보안 저장"
    ManagedBy   = "terraform"
  }
}

# Secrets Manager 시크릿 버전 (초기값 설정 - 선택사항)
# 보안 주의사항: 실제 민감 정보는 Terraform 코드에 직접 노출하지 마세요!
# 초기값은 플레이스홀더로 설정하고, 실제 값은 AWS 콘솔이나 CLI로 별도 설정하세요.
resource "aws_secretsmanager_secret_version" "this" {
  count = var.create_initial_version ? 1 : 0

  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.secret_string_value

  lifecycle {
    ignore_changes = [secret_string]
  }
}
