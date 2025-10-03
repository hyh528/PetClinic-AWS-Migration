# Secrets Manager 시크릿 생성
resource "aws_secretsmanager_secret" "this" {
  # 시크릿의 이름입니다.
  name        = var.secret_name
  # 시크릿의 설명입니다.
  description = var.secret_description
  # 시크릿에 대한 복구 기간 (기본 30일)을 설정합니다.
  recovery_window_in_days = var.recovery_window_in_days

  # 시크릿 태그입니다.
  tags = {
    Name        = var.secret_name
    Project     = var.project_name
    Environment = var.environment
  }
}

# Secrets Manager 시크릿 버전 (선택 사항: 초기 값 설정)
# 이 리소스는 시크릿의 초기 값을 설정하는 데 사용될 수 있습니다.
# 실제 민감 정보는 Terraform 코드에 직접 노출하지 않는 것이 좋습니다.
# 여기서는 플레이스홀더 값을 사용하거나, 이 리소스를 생략하고 수동으로 값을 추가할 수 있습니다.
resource "aws_secretsmanager_secret_version" "this" {
  # 시크릿의 ARN 또는 이름입니다.
  secret_id     = aws_secretsmanager_secret.this.id
  # 시크릿의 값입니다. 실제 비밀번호는 여기에 직접 넣지 마세요.
  secret_string = var.secret_string_initial_value
}