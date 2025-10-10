# ==========================================
# Security 레이어: IAM 정책 관리
# ==========================================
# 휘권이가 담당하는 보안 정책들
# RDS 관리 시크릿 접근 정책 등

# ==========================================
# RDS 관리 시크릿 접근 정책
# ==========================================
# manage_master_user_password로 생성된 RDS 시크릿 접근 권한
# 애플리케이션 ECS 태스크에 부여할 정책

resource "aws_iam_policy" "rds_secret_access" {
  name        = "petclinic-dev-rds-secret-access"
  description = "Access policy for RDS managed database secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:rds-db-credentials/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "arn:aws:kms:*:*:key/*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.ap-northeast-2.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "security"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# ==========================================
# 정책 출력 (다른 레이어에서 참조 가능)
# ==========================================

output "rds_secret_access_policy_arn" {
  description = "ARN of the RDS secret access policy"
  value       = aws_iam_policy.rds_secret_access.arn
}